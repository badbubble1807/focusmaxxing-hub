//! focusmaxxing setup - the computer step of the free tier.
//!
//! plug the phone in, sign in with the apple id, and Focusmaxxing Hub lands on the phone with its
//! pairing file in place. this is a trimmed fork of iloader by nab138 (MIT,
//! https://github.com/nab138/iloader): the phone, apple and signing code is iloader's, unchanged
//! apart from names; what is gone is everything a customer never needs (importing other apps, the
//! certificate and app id managers, the pairing manager, LiveContainer, the auto-updater, saved
//! passwords). the one thing added is the developer mode check (devmode.rs).
//!
//! every address is in links.rs; every piece of text the customer reads is in ../src/strings.ts.

mod account;
mod device;
mod devmode;
mod error;
mod links;
mod logging;
mod operation;
mod pairing;
mod secure_storage;
mod sideload;

use crate::{
    account::{invalidate_account, logged_in_as, login_new, reset_anisette_state},
    device::{DeviceInfoMutex, PairingCancelToken, cancel_pairing, list_devices, set_selected_device},
    devmode::developer_mode_status,
    pairing::{delete_stored_rppairing, has_stored_rppairing},
    secure_storage::{force_disable_keyring, keyring_available},
    sideload::{SideloaderMutex, install_hub_operation},
};
use tauri::Manager;
use tracing_subscriber::{Layer, Registry, fmt, layer::SubscriberExt, util::SubscriberInitExt};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::new().build())
        .setup(|app| {
            // the log file: %APPDATA%\com.focusmaxxing.setup\logs\focusmaxxing-setup.<date>.log
            let log_dir = app
                .path()
                .app_data_dir()
                .expect("failed to get app data dir")
                .join("logs");

            std::fs::create_dir_all(&log_dir).ok();

            let file_appender = tracing_appender::rolling::RollingFileAppender::builder()
                .rotation(tracing_appender::rolling::Rotation::DAILY)
                .filename_prefix("focusmaxxing-setup")
                .filename_suffix("log")
                .max_log_files(2)
                .build(&log_dir)
                .expect("failed to create log file appender");

            let file_layer = fmt::layer()
                .with_writer(file_appender)
                .with_target(true)
                .with_ansi(false)
                .with_filter(tracing_subscriber::filter::LevelFilter::DEBUG);

            let frontend_layer = logging::FrontendLoggingLayer::new(app.handle().clone())
                .with_filter(tracing_subscriber::filter::LevelFilter::DEBUG);

            Registry::default()
                .with(file_layer)
                .with(frontend_layer)
                .init();

            std::panic::set_hook(Box::new(|panic_info| {
                let thread = std::thread::current();
                let thread_name = thread.name().unwrap_or("<unnamed>");

                let message = if let Some(s) = panic_info.payload().downcast_ref::<&str>() {
                    s.to_string()
                } else if let Some(s) = panic_info.payload().downcast_ref::<String>() {
                    s.clone()
                } else {
                    "<non-string panic payload>".to_string()
                };

                let location = panic_info
                    .location()
                    .map(|loc| format!("{}:{}", loc.file(), loc.line()))
                    .unwrap_or_else(|| "<unknown>".to_string());

                let backtrace = std::backtrace::Backtrace::capture();

                tracing::error!(
                    target: "panic",
                    thread = thread_name,
                    location = location,
                    message = message,
                    backtrace = %backtrace,
                    "panic captured"
                );
            }));

            app.manage(DeviceInfoMutex::new(None));
            app.manage(SideloaderMutex::new(None));
            app.manage(PairingCancelToken::new(None));
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            login_new,
            invalidate_account,
            logged_in_as,
            reset_anisette_state,
            list_devices,
            set_selected_device,
            cancel_pairing,
            has_stored_rppairing,
            delete_stored_rppairing,
            install_hub_operation,
            developer_mode_status,
            keyring_available,
            force_disable_keyring,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
