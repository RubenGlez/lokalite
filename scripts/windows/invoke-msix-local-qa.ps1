[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet('Install', 'Inspect', 'VerifyAlias', 'Activate', 'Update')] [string] $Action,
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $IdentityName,
    [string] $Package,
    [string] $CandidatePackage,
    [string] $Alias = 'lokalite.exe',
    [string] $ApplicationId = 'Lokalite'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-SignedPackage([string] $Path) {
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $signature = Get-AuthenticodeSignature -LiteralPath $resolved
    if ($signature.Status -ne 'Valid') {
        throw "Local QA requires a package whose certificate is already trusted by this user. Signature status: $($signature.Status)"
    }
    return $resolved
}

function Get-InstalledPackage {
    $installed = @(Get-AppxPackage -Name $IdentityName)
    if ($installed.Count -ne 1) { throw "Expected one installed $IdentityName package; found $($installed.Count)." }
    return $installed[0]
}

Write-Warning 'Local sideload QA does not prove Store ingestion, Store signing, private-flight behavior, or Store-managed updates.'

switch ($Action) {
    'Install' {
        $resolved = Resolve-SignedPackage $Package
        Add-AppxPackage -Path $resolved
        Get-InstalledPackage | Select-Object Name, PackageFullName, PackageFamilyName, Version, SignatureKind, InstallLocation
    }
    'Inspect' {
        Get-InstalledPackage | Select-Object Name, PackageFullName, PackageFamilyName, Version, SignatureKind, InstallLocation
    }
    'VerifyAlias' {
        $null = Get-InstalledPackage
        $aliasPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\$Alias"
        if (-not (Test-Path -LiteralPath $aliasPath -PathType Leaf)) {
            throw "Execution alias not found or disabled: $aliasPath"
        }
        & $aliasPath --version
        if ($LASTEXITCODE -ne 0) { throw "$Alias --version failed with exit code $LASTEXITCODE" }
        & $aliasPath mcp --help
        if ($LASTEXITCODE -ne 0) { throw "$Alias mcp --help failed with exit code $LASTEXITCODE" }
    }
    'Activate' {
        $installed = Get-InstalledPackage
        $aumid = "$($installed.PackageFamilyName)!$ApplicationId"
        Start-Process explorer.exe -ArgumentList "shell:AppsFolder\$aumid"
        [pscustomobject]@{
            Aumid = $aumid
            ManualChecks = 'Confirm exactly one desktop/tray/daemon instance and no second Vault writer.'
        }
    }
    'Update' {
        $before = Get-InstalledPackage
        $resolved = Resolve-SignedPackage $CandidatePackage
        Add-AppxPackage -Path $resolved
        $after = Get-InstalledPackage
        if ([version] $after.Version -le [version] $before.Version) {
            throw "Candidate did not advance the installed version: $($before.Version) -> $($after.Version)"
        }
        [pscustomobject]@{
            Before = $before.Version
            After = $after.Version
            ManualChecks = 'Confirm the synthetic QA data, alias, startup preference, tray, and single broker remain intact.'
        }
    }
}
