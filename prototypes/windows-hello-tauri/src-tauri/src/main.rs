#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::Serialize;

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
async fn verify_with_windows_hello(window: tauri::Window) -> AuthenticationOutcome {
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

    AuthenticationOutcome::from_status(status)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![verify_with_windows_hello])
        .run(tauri::generate_context!())
        .expect("failed to run Tauri Windows Hello prototype");
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
