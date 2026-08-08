[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Artifact,
    [Parameter(Mandatory)] [ValidatePattern('^[0-9A-Fa-f]{40}$')] [string] $CertificateThumbprint,
    [string] $WindowsSdkRoot = $env:WindowsSdkDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$artifactPath = (Resolve-Path -LiteralPath $Artifact).Path
$certificate = Get-Item -LiteralPath "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction Stop
if (-not $certificate.HasPrivateKey) { throw 'The selected current-user certificate has no private key.' }

$signToolCommand = Get-Command signtool.exe -ErrorAction SilentlyContinue
$signToolPath = if ($signToolCommand) { $signToolCommand.Source } else { $null }
if (-not $signToolPath) {
    if (-not $WindowsSdkRoot) { throw 'SignTool was not found. Pass -WindowsSdkRoot or set WindowsSdkDir.' }
    $signToolPath = (Get-ChildItem -LiteralPath (Join-Path $WindowsSdkRoot 'bin') -Recurse -Filter signtool.exe |
        Where-Object { $_.FullName -match '[\\/]x64[\\/]signtool\.exe$' } |
        Sort-Object FullName -Descending |
        Select-Object -First 1).FullName
}
if (-not $signToolPath) { throw 'No x64 SignTool executable was found.' }

Write-Warning 'This signature is only for local installation QA. It is not Microsoft Store signing and cannot close the Store gate.'
& $signToolPath sign /sha1 $CertificateThumbprint /fd SHA256 $artifactPath
if ($LASTEXITCODE -ne 0) { throw 'SignTool failed.' }
& $signToolPath verify /pa /v $artifactPath
if ($LASTEXITCODE -ne 0) { throw 'The local signature could not be verified.' }
