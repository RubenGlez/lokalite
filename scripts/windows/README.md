# Windows MSIX tooling

This directory stages the future Tauri desktop executable and independent Rust
CLI/MCP executable into Windows 11 x64 and ARM64 MSIX packages and a combined
bundle. It uses Windows SDK `MakeAppx.exe`; the cross-platform MSIX SDK is not
accepted for the final bundle gate.

## Build

`package-msix.ps1` requires all identity values as arguments. Obtain the
immutable production `Identity Name`, `Publisher`, and display name from
Partner Center; do not infer them from the macOS bundle identity.

```powershell
./scripts/windows/package-msix.ps1 `
  -DesktopX64 ./artifacts/x64/Lokalite.exe `
  -CliX64 ./artifacts/x64/lokalite.exe `
  -DesktopArm64 ./artifacts/arm64/Lokalite.exe `
  -CliArm64 ./artifacts/arm64/lokalite.exe `
  -Version 3.0.0.0 `
  -IdentityName $env:LOKALITE_STORE_IDENTITY `
  -Publisher $env:LOKALITE_STORE_PUBLISHER `
  -PublisherDisplayName $env:LOKALITE_STORE_PUBLISHER_DISPLAY_NAME `
  -WindowsSdkRoot $env:WindowsSdkDir
```

The input CLI may retain its normal build filename. Inside the package it is
always `lokalite-cli.exe`; the public execution alias remains `lokalite.exe`.
The script rejects incorrect PE architecture or GUI/console subsystem values,
packs and unpacks each architecture, verifies manifest and payload contracts,
builds and unbundles the complete bundle, and writes `SHA256SUMS`.

## Local installation QA

Local sideloading is useful before a private flight, but it is not Store
evidence. `sign-msix-local.ps1` only accepts an existing current-user signing
certificate and does not create or trust one. The certificate subject must
match the manifest Publisher. Never use a local test identity as the production
Partner Center identity.

After signing and trusting the local test certificate, use
`invoke-msix-local-qa.ps1` explicitly for `Install`, `Inspect`, `VerifyAlias`,
`Activate`, and `Update`. The helper intentionally does not uninstall or delete
application data. Startup, tray/background, Windows Hello, daemon ownership,
and preservation of synthetic QA data remain witnessed manual checks.

Only an actual Partner Center submission and private-flight install/update can
close Store ingestion, Store signing, packaged capability, and Store-managed
update gates. Native ARM64 runtime QA is also required before ARM64 support can
be declared stable.
