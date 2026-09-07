// the apple id: signing in (email, password, the two-factor code the screen asks for) and the
// signing certificate apple hands out for this computer. iloader's account.rs without the saved
// passwords and without the certificate and app id managers. the password is never stored; the
// certificate and the sign-in state are, in the credential store, so the next run does not ask
// for a code again.

use futures::FutureExt;
use isideload::{
    anisette::remote_v3::RemoteV3AnisetteProvider,
    auth::apple_account::{AppleAccount, TwoFactorCallbackParams, TwoFactorCallbackResponse},
    dev::{certificates::DevelopmentCertificate, developer_session::DeveloperSession},
    sideload::{SideloaderBuilder, builder::MaxCertsBehavior, sideloader::Sideloader},
};
use keyring::Entry;
use rootcause::prelude::*;
use serde::{Deserialize, Serialize};
use std::time::Duration;
use tauri::{AppHandle, Emitter, Listener, State, Window};
use tracing::debug;

use crate::{
    error::AppError,
    links::{KEYRING_SERVICE, MACHINE_NAME},
    secure_storage::create_sideloading_storage,
    sideload::SideloaderMutex,
};

#[tauri::command]
pub async fn login_new(
    handle: AppHandle,
    window: Window,
    sideloader_state: State<'_, SideloaderMutex>,
    email: String,
    password: String,
    anisette_server: String,
) -> Result<(), AppError> {
    let account = login(&handle, &window, &email, &password, anisette_server).await?;
    let mut sideloader_guard = sideloader_state.lock().unwrap();
    *sideloader_guard = Some(account);
    Ok(())
}

#[tauri::command]
pub fn logged_in_as(sideloader_state: State<'_, SideloaderMutex>) -> Option<String> {
    let sideloader_guard = sideloader_state.lock().unwrap();
    if let Some(account) = &*sideloader_guard {
        return Some(account.get_email().to_string());
    }
    None
}

#[tauri::command]
pub fn invalidate_account(sideloader_state: State<'_, SideloaderMutex>) {
    let mut sideloader_guard = sideloader_state.lock().unwrap();
    *sideloader_guard = None;
}

// forgets the apple sign-in state, so the next sign-in asks for a two-factor code again
#[tauri::command]
pub fn reset_anisette_state() -> Result<bool, AppError> {
    let state_entry = Entry::new(KEYRING_SERVICE, "anisette_state").map_err(|e| {
        AppError::KeyringWithMessage(
            "Failed to create keyring entry for anisette".into(),
            e.to_string(),
        )
    })?;

    match state_entry.delete_credential() {
        Ok(_) => {
            debug!("Anisette state deleted from keyring.");
            Ok(true)
        }
        Err(keyring::Error::NoEntry) => {
            debug!("No existing anisette state found in keyring, nothing to delete.");
            Ok(false)
        }
        Err(e) => Err(AppError::KeyringWithMessage(
            "Failed to delete anisette state".into(),
            e.to_string(),
        )),
    }
}

async fn login(
    app: &AppHandle,
    window: &Window,
    email: &str,
    password: &str,
    anisette_server: String,
) -> Result<Sideloader, AppError> {
    let tfa_closure = {
        let window_clone = window.clone();
        move |params: TwoFactorCallbackParams| {
            let window_clone = window_clone.clone();

            async move {
                window_clone
                    .emit("2fa-required", params)
                    .context("Failed to emit 2fa-required event")?;

                let (tx, rx) = std::sync::mpsc::channel::<String>();
                let handler_id = window_clone.listen("2fa-recieved", move |event| {
                    let code = event.payload();
                    let _ = tx.send(code.to_string());
                });

                let result = rx.recv_timeout(Duration::from_secs(120))?;
                window_clone.unlisten(handler_id);

                let code = result.trim_matches('"').to_string();
                Ok(TwoFactorCallbackResponse::SubmitCode(code))
            }
            .boxed()
        }
    };

    let anisette_url = if !anisette_server.starts_with("http") {
        format!("https://{}", anisette_server)
    } else {
        anisette_server
    };

    let mut account = AppleAccount::builder(&email.to_lowercase())
        .anisette_provider(
            RemoteV3AnisetteProvider::default()?
                .set_serial_number("0".to_string())
                .set_storage(create_sideloading_storage(app)?)
                .set_url(&anisette_url),
        )
        .login(password, Box::new(tfa_closure))
        .await?;

    debug!("Logged in");

    let dev_session = DeveloperSession::from_account(&mut account).await?;

    debug!("Created developer session");

    let max_certs_callback = {
        let window_clone = window.clone();
        move |certs: &Vec<DevelopmentCertificate>| -> Option<Vec<String>> {
            let cert_infos: Vec<CertificateInfo> = certs
                .iter()
                .map(|cert| CertificateInfo {
                    name: cert.name.clone(),
                    certificate_id: cert.certificate_id.clone(),
                    serial_number: cert.serial_number.clone(),
                    machine_name: cert.machine_name.clone(),
                    machine_id: cert.machine_id.clone(),
                })
                .collect();
            window_clone
                .emit("max-certs-reached", cert_infos)
                .expect("Failed to emit max-certs-reached event");

            let (tx, rx) = std::sync::mpsc::channel::<Option<Vec<String>>>();
            let handler_id = window_clone.listen("max-certs-response", move |event| {
                let certs = event.payload();
                let certs = serde_json::from_str::<Option<Vec<String>>>(certs).unwrap_or(None);
                let _ = tx.send(certs);
            });

            let result = rx.recv_timeout(Duration::from_secs(300));
            window_clone.unlisten(handler_id);
            result.unwrap_or(None)
        }
    };

    let sideloader = SideloaderBuilder::new(dev_session, email.to_lowercase())
        .machine_name(MACHINE_NAME.into())
        .storage(create_sideloading_storage(app)?)
        .max_certs_behavior(MaxCertsBehavior::Prompt(Box::new(max_certs_callback)))
        .build();

    debug!("Built sideloader");

    Ok(sideloader)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CertificateInfo {
    pub name: Option<String>,
    pub certificate_id: Option<String>,
    pub serial_number: Option<String>,
    pub machine_name: Option<String>,
    pub machine_id: Option<String>,
}
