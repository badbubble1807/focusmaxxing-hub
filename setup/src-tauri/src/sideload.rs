// downloads the hub and puts it on the phone: download, sign for this apple id and install, drop
// the pairing file into the hub, check developer mode. iloader's sideload.rs trimmed to that one
// job; "import any app" and the LiveContainer variants are gone.

use std::{path::PathBuf, sync::Mutex};

use crate::{
    device::{DeviceInfoMutex, get_provider, get_provider_from_connection, get_usbmuxd},
    devmode,
    error::AppError,
    links::{HUB_IPA_URL, HUB_PAIRING_FILE},
    operation::Operation,
    pairing::{get_hub_bundle_id, place_file},
};
use isideload::sideload::{application::SpecialApp, sideloader::Sideloader};
use serde::Serialize;
use tauri::{AppHandle, Manager, State, Window};
use tracing::{info, warn};

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
            bundle_id,
            HUB_PAIRING_FILE.to_string(),
        )
        .await,
    )?;
    op.move_on("pairing", "devmode")?;

    // 4. developer mode: read it and reveal the switch. never fails the install
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
