// downloads the hub and puts it on the phone: download, sign for this apple id and install, drop
// the pairing file into the hub, check developer mode. iloader's sideload.rs trimmed to that one
// job; "import any app" and the LiveContainer variants are gone.

use std::{path::PathBuf, sync::Mutex};

use crate::{
    device::{DeviceInfoMutex, get_provider, get_provider_from_connection, get_usbmuxd},
    devmode,
    error::AppError,
    links::{HUB_CERTIFICATE_FILE, HUB_IPA_URL, HUB_PAIRING_FILE, MACHINE_NAME},
    operation::Operation,
    pairing::{get_hub_bundle_id, place_file},
    secure_storage::create_sideloading_storage,
};
use idevice::provider::IdeviceProvider;
use isideload::{
    dev::certificates::CertificatesApi,
    sideload::{
        application::SpecialApp, builder::MaxCertsBehavior, cert_identity::CertificateIdentity,
        sideloader::Sideloader,
    },
};
use rsa::pkcs8::EncodePrivateKey;
use serde::Serialize;
use tauri::{AppHandle, Manager, State, Window};
use tracing::{info, warn};
use x509_cert::der::Encode;

pub type SideloaderMutex = Mutex<Option<Sideloader>>;

pub struct SideloaderGuard<'a> {
    state: &'a SideloaderMutex,
    sideloader: Option<Sideloader>,
}

impl<'a> SideloaderGuard<'a> {
    pub fn take(state: &'a SideloaderMutex) -> Result<Self, AppError> {
        let mut guard = state.lock().unwrap();
        let sideloader = guard.take().ok_or(AppError::NotLoggedIn)?;
        Ok(Self {
            state,
            sideloader: Some(sideloader),
        })
    }

    pub fn get_mut(&mut self) -> &mut Sideloader {
        self.sideloader
            .as_mut()
            .expect("Sideloader should be present")
    }
}

impl Drop for SideloaderGuard<'_> {
    fn drop(&mut self) {
        let mut guard = self.state.lock().unwrap();
        *guard = self.sideloader.take();
    }
}

async fn sideload(
    device_state: State<'_, DeviceInfoMutex>,
    sideloader_state: State<'_, SideloaderMutex>,
    app_path: String,
) -> Result<Option<SpecialApp>, AppError> {
    let device = {
        let device_lock = device_state.lock().unwrap();
        match &*device_lock {
            Some(d) => d.clone(),
            None => return Err(AppError::NoDeviceSelected),
        }
    };

    let provider = get_provider(&device.info).await?;

    let mut sideloader = SideloaderGuard::take(&sideloader_state)?;

    let special = sideloader
        .get_mut()
        .install_app(
            &provider,
            app_path.into(),
            false,
            None::<fn(f32) -> std::future::Ready<()>>,
        )
        .await?;

    Ok(special)
}

// what the screen learns when the install is through
#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct HubInstallResult {
    // true = developer mode was already on; None = the phone would not say
    pub developer_mode: Option<bool>,
}

#[tauri::command]
pub async fn install_hub_operation(
    handle: AppHandle,
    window: Window,
    device_state: State<'_, DeviceInfoMutex>,
    sideloader_state: State<'_, SideloaderMutex>,
) -> Result<HubInstallResult, AppError> {
    let op = Operation::new("install_hub".to_string(), &window);

    // 1. download the hub as the "build hub" workflow published it
    op.start("download")?;
    let dest = handle
        .path()
        .temp_dir()
        .map_err(|e| AppError::Filesystem("Failed to get temp dir".into(), e.to_string()))?
        .join("focusmaxxing-hub.ipa");
    op.fail_if_err("download", download(HUB_IPA_URL, &dest).await)?;
    op.move_on("download", "install")?;

    // 2. sign it for this apple id and this phone, and install it
    let device = {
        let device_guard = device_state.lock().unwrap();
        match &*device_guard {
            Some(d) => d.clone(),
            None => return op.fail("install", AppError::NoDeviceSelected),
        }
    };
    let special = op.fail_if_err(
        "install",
        sideload(
            device_state,
            sideloader_state,
            dest.to_string_lossy().to_string(),
        )
        .await,
    )?;
    match special {
        Some(SpecialApp::SideStore) => info!("the hub was recognised as a store app; its certificate is baked in"),
        Some(other) => warn!("the hub was signed as {other}, not as a store app; it may not be able to renew itself"),
        None => warn!("the hub was not recognised as a store app; it may not be able to renew itself"),
    }
    op.move_on("install", "pairing")?;

    // 3. put the pairing file where the hub looks for it
    let bundle_id = op.fail_if_err("pairing", get_hub_bundle_id(&device.info).await)?;
    let Some(bundle_id) = bundle_id else {
        return op.fail(
            "pairing",
            AppError::HouseArrest(
                "Focusmaxxing Hub was not found on the phone".into(),
                "The phone did not list the hub among its installed apps".into(),
            ),
        );
    };
    let mut usbmuxd = op.fail_if_err("pairing", get_usbmuxd().await)?;
    let provider = op.fail_if_err(
        "pairing",
        get_provider_from_connection(&device.info, &mut usbmuxd).await,
    )?;
    op.fail_if_err(
        "pairing",
        place_file(
            device.pairing,
            &provider,
            bundle_id.clone(),
            HUB_PAIRING_FILE.to_string(),
        )
        .await,
    )?;

    op.move_on("pairing", "certificate")?;

    // 4. the signing certificate, into the same folder. this is what stops the hub asking apple
    // for a certificate of its own the first time it is opened; see hand_certificate_to_hub.
    op.fail_if_err(
        "certificate",
        hand_certificate_to_hub(&handle, &provider, bundle_id).await,
    )?;
    op.move_on("certificate", "devmode")?;

    // 5. developer mode: read it and reveal the switch. never fails the install
    let developer_mode = match devmode::status_and_reveal(&device.info).await {
        Ok(on) => Some(on),
        Err(e) => {
            warn!("could not read developer mode: {e}");
            None
        }
    };
    op.complete("devmode")?;
    info!("hub installed; developer mode {:?}", developer_mode);
    Ok(HubInstallResult { developer_mode })
}

// writes the signing certificate this computer just used into the hub's own Documents folder,
// next to the pairing file, as its two raw pieces: the certificate apple issued and the private
// key that goes with it.
//
// why it is worth a step of its own: the signing library already bakes the same certificate into
// the hub as ALTCertificate.p12, locked with the "machine id" apple gave it, and the hub is meant
// to work that password out again from apple's certificate list. on the owner's phone it did not
// (2026-09-07: "No signable certificate found for serial 2E30F41A..."), so the hub asked apple for
// a certificate of its own - and a free apple id only keeps one, so apple took this one away. the
// hub was then wearing a revoked certificate: the two custom apps stopped being renewable and the
// hub demanded to be re-signed. handing the certificate over ourselves, with no password and no
// archive format in the way, is the one form of it nothing can misread.
async fn hand_certificate_to_hub(
    handle: &AppHandle,
    provider: &dyn IdeviceProvider,
    bundle_id: String,
) -> Result<(), AppError> {
    let sideloader_state = handle.state::<SideloaderMutex>();
    let mut sideloader = SideloaderGuard::take(&sideloader_state)?;

    let team = sideloader.get_mut().get_team().await?;
    let email = sideloader.get_mut().get_email().to_string();
    let storage = create_sideloading_storage(handle)?;

    // the serial numbers apple already has. the lookup below cannot make a certificate (it is
    // told to fail instead), but if it somehow came back with one apple did not have a moment
    // ago, it would not be the one the hub was just signed with, and handing that over would
    // leave the hub wearing one certificate and signing with another.
    let known_serials: Vec<String> = sideloader
        .get_mut()
        .get_dev_session()
        .list_ios_certs(&team)
        .await?
        .iter()
        .filter_map(|cert| cert.serial_number.clone())
        .collect();

    let identity = CertificateIdentity::retrieve(
        MACHINE_NAME,
        &email,
        sideloader.get_mut().get_dev_session(),
        &team,
        storage.as_ref(),
        &MaxCertsBehavior::Error,
    )
    .await?;

    let serial = identity.get_serial_number();
    if !known_serials.is_empty() && !known_serials.iter().any(|known| same_serial(known, &serial)) {
        return Err(AppError::Misc(
            "Could not hand the signing certificate to Focusmaxxing Hub: the certificate found was not the one it was signed with. Try again.".into(),
        ));
    }

    let certificate_der = identity
        .certificate
        .to_der()
        .map_err(|e| AppError::Misc(format!("Failed to write out the certificate: {e}")))?;
    let private_key_der = identity
        .private_key
        .to_pkcs8_der()
        .map_err(|e| AppError::Misc(format!("Failed to write out the private key: {e}")))?
        .as_bytes()
        .to_vec();

    let mut contents = plist::Dictionary::new();
    contents.insert("certificate".into(), plist::Value::Data(certificate_der));
    contents.insert("privateKey".into(), plist::Value::Data(private_key_der));
    contents.insert("serialNumber".into(), plist::Value::String(serial.clone()));
    contents.insert(
        "machineName".into(),
        plist::Value::String(identity.machine_name.clone()),
    );
    contents.insert(
        "machineId".into(),
        plist::Value::String(identity.machine_id.clone()),
    );

    let mut bytes: Vec<u8> = Vec::new();
    plist::Value::Dictionary(contents)
        .to_writer_xml(&mut bytes)
        .map_err(|e| AppError::Misc(format!("Failed to write out the certificate file: {e}")))?;

    place_file(bytes, provider, bundle_id, HUB_CERTIFICATE_FILE.to_string()).await?;
    info!("handed the signing certificate (serial {serial}) to the hub");

    Ok(())
}

// apple's serial numbers turn up spelled two ways: with the leading zeros and without. the hub
// compares them the same way (FMXCertificateHandoff.sameSerial).
fn same_serial(one: &str, other: &str) -> bool {
    let strip = |serial: &str| serial.to_uppercase().trim_start_matches('0').to_string();
    !one.is_empty() && !other.is_empty() && strip(one) == strip(other)
}

pub async fn download(url: impl AsRef<str>, dest: &PathBuf) -> Result<(), AppError> {
    // the customer sees the error text, so the address (with its file name) stays in the log only
    let response = reqwest::get(url.as_ref()).await.map_err(|e| {
        warn!("download failed: {e}");
        AppError::Download("Could not download Focusmaxxing Hub".into())
    })?;
    if !response.status().is_success() {
        return Err(AppError::Download(format!(
            "Could not download Focusmaxxing Hub: HTTP {}",
            response.status()
        )));
    }

    let bytes = response.bytes().await.map_err(|e| {
        warn!("download failed while reading: {e}");
        AppError::Download("Could not download Focusmaxxing Hub".into())
    })?;
    tokio::fs::write(dest, &bytes).await.map_err(|e| {
        AppError::Filesystem("Failed to write downloaded file".into(), e.to_string())
    })?;

    Ok(())
}
