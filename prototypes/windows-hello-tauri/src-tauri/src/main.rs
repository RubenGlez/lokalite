#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod lifecycle;

use std::sync::Mutex;

use lifecycle::{LifecycleAction, LifecycleEvent, LifecycleState};
use serde::Serialize;
use tauri::{
    AppHandle, Manager, RunEvent, WindowEvent,
    menu::{Menu, MenuItem},
    tray::TrayIconBuilder,
};

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
enum AuthenticationStatus {
    Verified,
    Canceled,
    Unavailable,
    Failed,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct AuthenticationOutcome {
    status: AuthenticationStatus,
    session_started: bool,
    fallback_offered: bool,
}

impl AuthenticationOutcome {
    fn from_status(status: AuthenticationStatus) -> Self {
        Self {
            status,
            session_started: status == AuthenticationStatus::Verified,
            fallback_offered: false,
        }
    }
}

#[cfg(windows)]
mod windows_hello {
    use super::AuthenticationStatus;
    use tauri::Window;
    use windows::{
        Security::Credentials::UI::{
            UserConsentVerificationResult, UserConsentVerifier, UserConsentVerifierAvailability,
        },
        Win32::{Foundation::HWND, System::WinRT::IUserConsentVerifierInterop},
        core::{HRESULT, HSTRING, factory},
    };
    use windows_future::IAsyncOperation;

    fn map_result(result: UserConsentVerificationResult) -> AuthenticationStatus {
        match result {
            UserConsentVerificationResult::Verified => AuthenticationStatus::Verified,
            UserConsentVerificationResult::Canceled => AuthenticationStatus::Canceled,
            UserConsentVerificationResult::DeviceNotPresent
            | UserConsentVerificationResult::NotConfiguredForUser
            | UserConsentVerificationResult::DisabledByPolicy
            | UserConsentVerificationResult::DeviceBusy => AuthenticationStatus::Unavailable,
            UserConsentVerificationResult::RetriesExhausted => AuthenticationStatus::Failed,
            _ => AuthenticationStatus::Failed,
        }
    }

    fn availability_allows_prompt(
        availability: UserConsentVerifierAvailability,
    ) -> Result<(), AuthenticationStatus> {
        match availability {
            UserConsentVerifierAvailability::Available => Ok(()),
            UserConsentVerifierAvailability::DeviceNotPresent
            | UserConsentVerifierAvailability::NotConfiguredForUser
            | UserConsentVerifierAvailability::DisabledByPolicy
            | UserConsentVerifierAvailability::DeviceBusy => Err(AuthenticationStatus::Unavailable),
            _ => Err(AuthenticationStatus::Failed),
        }
    }

    pub fn verify(window: &Window, reason: &str) -> AuthenticationStatus {
        verify_inner(window, reason).unwrap_or(AuthenticationStatus::Failed)
    }

    fn verify_inner(window: &Window, reason: &str) -> windows::core::Result<AuthenticationStatus> {
        let availability = UserConsentVerifier::CheckAvailabilityAsync()?.join()?;
        if let Err(status) = availability_allows_prompt(availability) {
            return Ok(status);
        }

        let tauri_hwnd = window.hwnd().map_err(|error| {
            windows::core::Error::new(HRESULT(0x8000_4005_u32 as i32), error.to_string())
        })?;
        if tauri_hwnd.0.is_null() {
            return Ok(AuthenticationStatus::Failed);
        }

        // Tauri and this prototype may resolve different windows crate patch
        // versions. Only the native pointer value crosses that crate boundary.
        let hwnd = HWND(tauri_hwnd.0);
        let interop: IUserConsentVerifierInterop =
            factory::<UserConsentVerifier, IUserConsentVerifierInterop>()?;
        let operation: IAsyncOperation<UserConsentVerificationResult> =
            unsafe { interop.RequestVerificationForWindowAsync(hwnd, &HSTRING::from(reason))? };

        Ok(map_result(operation.join()?))
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn verification_results_fail_closed() {
            assert_eq!(
                map_result(UserConsentVerificationResult::Verified),
                AuthenticationStatus::Verified
            );
            assert_eq!(
                map_result(UserConsentVerificationResult::Canceled),
                AuthenticationStatus::Canceled
            );
            assert_eq!(
                map_result(UserConsentVerificationResult::DeviceNotPresent),
                AuthenticationStatus::Unavailable
            );
            assert_eq!(
                map_result(UserConsentVerificationResult::RetriesExhausted),
                AuthenticationStatus::Failed
            );
        }

        #[test]
        fn only_available_authentication_may_prompt() {
            assert_eq!(
                availability_allows_prompt(UserConsentVerifierAvailability::Available),
                Ok(())
            );
            assert_eq!(
                availability_allows_prompt(UserConsentVerifierAvailability::NotConfiguredForUser),
                Err(AuthenticationStatus::Unavailable)
            );
        }
    }
}

#[tauri::command]
async fn verify_with_windows_hello(app: AppHandle, window: tauri::Window) -> AuthenticationOutcome {
    #[cfg(windows)]
    let status = tauri::async_runtime::spawn_blocking(move || {
        windows_hello::verify(
            &window,
            "Verify your identity to test the Lokalite Vault boundary",
        )
    })
    .await
    .unwrap_or(AuthenticationStatus::Failed);

    #[cfg(not(windows))]
    let status = {
        let _ = window;
        AuthenticationStatus::Unavailable
    };

    let outcome = AuthenticationOutcome::from_status(status);
    if outcome.session_started {
        lifecycle_state(&app)
            .lock()
            .expect(LOCK_POISONED)
            .start_session();
    }

    outcome
}

/// Exposes the observed lifecycle state so interactive QA reads recorded facts
/// instead of inferring them from the window's appearance.
#[tauri::command]
fn read_lifecycle_state(app: AppHandle) -> LifecycleState {
    *lifecycle_state(&app).lock().expect(LOCK_POISONED)
}

const LOCK_POISONED: &str = "lifecycle state mutex poisoned";

fn lifecycle_state(app: &AppHandle) -> tauri::State<'_, Mutex<LifecycleState>> {
    app.state::<Mutex<LifecycleState>>()
}

/// Applies one lifecycle event and performs the single action it allows.
fn drive_lifecycle(app: &AppHandle, event: LifecycleEvent) {
    let action = lifecycle_state(app)
        .lock()
        .expect(LOCK_POISONED)
        .apply(event);

    match action {
        // The window is hidden, never destroyed: this process stays the one
        // broker that owns the Vault key.
        LifecycleAction::HideToTray => {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.hide();
            }
        }
        LifecycleAction::FocusExistingWindow => {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.unminimize();
                let _ = window.set_focus();
            }
        }
        LifecycleAction::ExitApplication => app.exit(0),
    }
}

fn build_tray(app: &AppHandle) -> tauri::Result<()> {
    let show = MenuItem::with_id(app, "show", "Show prototype", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
    let menu = Menu::with_items(app, &[&show, &quit])?;

    TrayIconBuilder::with_id("lokalite-prototype")
        .icon(tauri::include_image!("icons/icon.ico"))
        .tooltip("Lokalite Windows Hello prototype")
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id().as_ref() {
            "show" => drive_lifecycle(app, LifecycleEvent::ShowRequested),
            "quit" => drive_lifecycle(app, LifecycleEvent::QuitRequested),
            _ => {}
        })
        .build(app)?;

    Ok(())
}

fn main() {
    tauri::Builder::default()
        // Must stay the first plugin: a second launch has to be absorbed
        // before it can build a window or claim the broker.
        .plugin(tauri_plugin_single_instance::init(|app, _argv, _cwd| {
            drive_lifecycle(app, LifecycleEvent::SecondInstanceLaunched);
        }))
        .manage(Mutex::new(LifecycleState::default()))
        .setup(|app| {
            build_tray(app.handle())?;
            Ok(())
        })
        .on_window_event(|window, event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                // Closing the window must not end the background service.
                api.prevent_close();
                drive_lifecycle(window.app_handle(), LifecycleEvent::WindowCloseRequested);
            }
        })
        .invoke_handler(tauri::generate_handler![
            verify_with_windows_hello,
            read_lifecycle_state
        ])
        .build(tauri::generate_context!())
        .expect("failed to build Tauri Windows Hello prototype")
        .run(|_app, event| {
            // `code` is set only when the tray's Quit called `app.exit`. Any
            // other exit request (such as the last window disappearing) is
            // refused so the tray keeps the process alive.
            if let RunEvent::ExitRequested {
                code: None, api, ..
            } = event
            {
                api.prevent_exit();
            }
        });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_verified_starts_a_session() {
        for status in [
            AuthenticationStatus::Canceled,
            AuthenticationStatus::Unavailable,
            AuthenticationStatus::Failed,
        ] {
            let outcome = AuthenticationOutcome::from_status(status);
            assert!(!outcome.session_started);
            assert!(!outcome.fallback_offered);
        }

        let verified = AuthenticationOutcome::from_status(AuthenticationStatus::Verified);
        assert!(verified.session_started);
        assert!(!verified.fallback_offered);
    }
}
