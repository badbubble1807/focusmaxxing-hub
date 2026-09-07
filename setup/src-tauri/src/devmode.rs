// developer mode on the phone. an app signed with a personal apple id only opens once developer
// mode is on (Settings → Privacy & Security → Developer Mode), and the phone keeps that switch
// hidden until something asks for it. this asks, and reads whether it is already on, so the last
// screen can say the right thing. the service and its actions come from the idevice crate by
// jkcoxson (src/services/amfi.rs at the pinned version); the phone answers, it is not changed.
//
// switching developer mode on from here is not done on purpose: apple only allows it when the
// phone has no passcode, and the pairing needs a passcode, so it would fail for everyone.

use idevice::{IdeviceService, amfi::AmfiClient};
use tauri::State;
use tracing::{info, warn};

use crate::{
    device::{DeviceInfo, DeviceInfoMutex, get_provider},
    error::AppError,
};

// reads developer mode; when it is off, makes the switch show up in the phone's Settings.
// true = on
pub async fn status_and_reveal(device: &DeviceInfo) -> Result<bool, AppError> {
    let provider = get_provider(device).await?;
    let mut amfi = AmfiClient::connect(&provider).await.map_err(|e| {
        AppError::DeviceComsWithMessage(
            "Failed to reach the developer mode service".into(),
            e.to_string(),
        )
    })?;
    let on = amfi.get_developer_mode_status().await.map_err(|e| {
        AppError::DeviceComsWithMessage("Failed to read developer mode".into(), e.to_string())
    })?;
    info!("developer mode is {}", if on { "on" } else { "off" });
    if !on {
        if let Err(e) = amfi.reveal_developer_mode_option_in_ui().await {
            warn!("could not reveal the developer mode switch: {e}");
        }
    }
    Ok(on)
}

// the "check again" button on the last screen
#[tauri::command]
pub async fn developer_mode_status(
    device_state: State<'_, DeviceInfoMutex>,
) -> Result<bool, AppError> {
    let device = {
        let guard = device_state.lock().unwrap();
        match &*guard {
            Some(d) => d.info.clone(),
            None => return Err(AppError::NoDeviceSelected),
        }
    };
    status_and_reveal(&device).await
}
