# Tauri Windows Hello and lifecycle prototype

This versioned Phase 0 prototype proves two Windows desktop seams.

**Authentication.** It obtains the real native `HWND` from a Tauri 2 window and
passes that exact handle to
`IUserConsentVerifierInterop::RequestVerificationForWindowAsync`.

**Background lifecycle.** It proves that closing the window keeps exactly one
process alive in the tray, and that a second launch is absorbed by the running
instance rather than becoming a second Vault writer. The rules live in
`src/lifecycle.rs` as a state machine with unit tests; the Tauri event loop may
only perform the action that machine returns.

It is deliberately isolated from Lokalite production code and data. It does not
open a Vault, access DPAPI material, create a Session, or offer an application
password. The UI receives only a typed authentication outcome.

## Build checks

Use the repository-authorized portable Node runtime:

```powershell
$env:PATH = 'C:\Users\María\tools\node-v24.19.0-win-x64;C:\Users\María\.cargo\bin;' + $env:PATH
corepack pnpm install --frozen-lockfile
corepack pnpm tauri build --no-bundle
```

### Automated lifecycle check

```powershell
./scripts/windows/invoke-lifecycle-qa.ps1 `
  -Executable ./prototypes/windows-hello-tauri/src-tauri/target/release/lokalite-windows-hello-tauri-prototype.exe
```

### ARM64

```powershell
rustup target add aarch64-pc-windows-msvc
cargo build --release --target aarch64-pc-windows-msvc
```

Everything compiles for ARM64, but linking needs the ARM64 MSVC toolset. If
`link.exe` is reported missing, add the
`Microsoft.VisualStudio.Component.VC.Tools.ARM64` component to the Visual Studio
Build Tools installation. Running ARM64 binaries still needs real hardware.

## Interactive QA

```powershell
$env:PATH = 'C:\Users\María\tools\node-v24.19.0-win-x64;C:\Users\María\.cargo\bin;' + $env:PATH
corepack pnpm tauri dev
```

1. Focus the prototype window and select **Verify with Windows Hello**.
2. Complete Windows Hello. The result must be `verified`.
3. Select the button again and cancel the system dialog. The result must be
   `canceled`, `sessionStarted: false`, and `fallbackOffered: false`.
4. Disable or unconfigure Windows Hello and repeat. The result must be
   `unavailable`, with no application-password path.

### Background lifecycle

Run the built executable directly (not `tauri dev`, which owns the process
tree), then:

1. Close the window with its close button. The window disappears, the tray icon
   remains, and the process keeps running.
2. Launch the executable again. No second process appears; the first window
   returns to the foreground.
3. Select **Read lifecycle state**. `brokersRunning` must be `1` and
   `absorbedLaunches` must equal the number of extra launches.
4. Verify with Windows Hello, close the window, and launch again. The absorbed
   launch must not change `sessionStarted`.
5. Choose **Quit** from the tray menu. The process exits; nothing survives.

Passing these checks proves the HWND comes from a real Tauri window and that the
tray keeps one background broker across window closes and repeated launches. It
does not yet prove DPAPI isolation, a second-user boundary, concurrent prompt
behavior, or installed MSIX lifecycle — an installed package can move the
single-instance identity and the startup task, so these checks must be repeated
against a Store-signed install.
