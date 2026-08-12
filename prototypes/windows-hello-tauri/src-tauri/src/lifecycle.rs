//! Deterministic desktop-lifecycle rules for the Phase 0 Windows prototype.
//!
//! The shipped product makes the desktop application the sole owner of the
//! Vault key (ADR 0014). That ownership only holds if closing the window keeps
//! exactly one background broker alive and a second launch never becomes a
//! second Vault writer. Those rules live here, away from the Tauri event loop,
//! so they can be asserted without a window server.

use serde::Serialize;

/// Everything the desktop shell can ask the lifecycle to do.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum LifecycleEvent {
    /// The user pressed the window's close button.
    WindowCloseRequested,
    /// Another process for the same user launched the application again.
    SecondInstanceLaunched,
    /// The user asked for the window from the tray.
    ShowRequested,
    /// The user chose Quit from the tray menu.
    QuitRequested,
}

/// What the shell must do in response. The shell may not invent other actions.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum LifecycleAction {
    /// Keep running in the tray with no visible window.
    HideToTray,
    /// Reveal and focus the window that already exists.
    FocusExistingWindow,
    /// Tear the broker down and exit the process.
    ExitApplication,
}

/// Observable lifecycle state, mirrored to the UI so manual QA reads facts
/// rather than trusting the window's appearance.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LifecycleState {
    pub window_visible: bool,
    /// Brokers owning the prototype's single-instance claim. Must never exceed 1.
    pub brokers_running: u32,
    /// Launches this process absorbed without starting another broker.
    pub absorbed_launches: u32,
    /// A background application is not an authenticated one.
    pub session_started: bool,
}

impl Default for LifecycleState {
    fn default() -> Self {
        Self {
            window_visible: true,
            brokers_running: 1,
            absorbed_launches: 0,
            session_started: false,
        }
    }
}

impl LifecycleState {
    /// Applies one shell event and reports the single action the shell may take.
    pub fn apply(&mut self, event: LifecycleEvent) -> LifecycleAction {
        match event {
            // Closing the window must not end the process: the broker keeps
            // serving CLI and MCP clients from the tray.
            LifecycleEvent::WindowCloseRequested => {
                self.window_visible = false;
                LifecycleAction::HideToTray
            }
            // A second launch is absorbed by the running instance. It never
            // starts another broker and never grants a session on its own.
            LifecycleEvent::SecondInstanceLaunched => {
                self.absorbed_launches += 1;
                self.window_visible = true;
                LifecycleAction::FocusExistingWindow
            }
            LifecycleEvent::ShowRequested => {
                self.window_visible = true;
                LifecycleAction::FocusExistingWindow
            }
            // Only an explicit quit stops the broker.
            LifecycleEvent::QuitRequested => {
                self.window_visible = false;
                self.brokers_running = 0;
                self.session_started = false;
                LifecycleAction::ExitApplication
            }
        }
    }

    /// Records that Windows Hello verified the user in this instance.
    pub fn start_session(&mut self) {
        self.session_started = true;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn closing_the_window_keeps_the_single_broker_alive() {
        let mut state = LifecycleState::default();

        assert_eq!(
            state.apply(LifecycleEvent::WindowCloseRequested),
            LifecycleAction::HideToTray
        );

        assert!(!state.window_visible);
        assert_eq!(state.brokers_running, 1);
    }

    #[test]
    fn a_second_launch_never_starts_a_second_broker() {
        let mut state = LifecycleState::default();
        state.apply(LifecycleEvent::WindowCloseRequested);

        for expected_absorbed in 1..=3 {
            assert_eq!(
                state.apply(LifecycleEvent::SecondInstanceLaunched),
                LifecycleAction::FocusExistingWindow
            );
            assert_eq!(state.absorbed_launches, expected_absorbed);
            assert_eq!(state.brokers_running, 1);
        }
    }

    #[test]
    fn a_second_launch_never_grants_a_session() {
        let mut state = LifecycleState::default();

        state.apply(LifecycleEvent::SecondInstanceLaunched);

        assert!(!state.session_started);
    }

    #[test]
    fn a_verified_session_does_not_survive_quitting() {
        let mut state = LifecycleState::default();
        state.start_session();
        assert!(state.session_started);

        assert_eq!(
            state.apply(LifecycleEvent::QuitRequested),
            LifecycleAction::ExitApplication
        );

        assert_eq!(state.brokers_running, 0);
        assert!(!state.session_started);
    }

    #[test]
    fn hiding_and_reshowing_never_authenticates_by_itself() {
        let mut state = LifecycleState::default();

        state.apply(LifecycleEvent::WindowCloseRequested);
        assert_eq!(
            state.apply(LifecycleEvent::ShowRequested),
            LifecycleAction::FocusExistingWindow
        );

        assert!(state.window_visible);
        assert!(!state.session_started);
    }

    #[test]
    fn only_quit_exits_the_application() {
        for event in [
            LifecycleEvent::WindowCloseRequested,
            LifecycleEvent::SecondInstanceLaunched,
            LifecycleEvent::ShowRequested,
        ] {
            let mut state = LifecycleState::default();
            assert_ne!(state.apply(event), LifecycleAction::ExitApplication);
            assert_eq!(state.brokers_running, 1);
        }
    }
}
