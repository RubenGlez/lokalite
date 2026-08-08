# Tauri Windows Hello HWND prototype

This versioned Phase 0 prototype proves the remaining application-window seam:
it obtains the real native `HWND` from a Tauri 2 window and passes that exact
handle to `IUserConsentVerifierInterop::RequestVerificationForWindowAsync`.

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

Passing these checks proves the HWND comes from a real Tauri window. It does not
yet prove DPAPI isolation, a second-user boundary, concurrent prompt behavior,
or installed MSIX lifecycle.
