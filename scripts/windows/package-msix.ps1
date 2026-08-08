[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $DesktopX64,
    [Parameter(Mandatory)] [string] $CliX64,
    [Parameter(Mandatory)] [string] $DesktopArm64,
    [Parameter(Mandatory)] [string] $CliArm64,
    [Parameter(Mandatory)] [ValidatePattern('^\d+\.\d+\.\d+\.\d+$')] [string] $Version,
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $IdentityName,
    [Parameter(Mandatory)] [ValidatePattern('^CN=.+')] [string] $Publisher,
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $PublisherDisplayName,
    [string] $OutputDirectory = (Join-Path $PSScriptRoot '..\..\.build\windows-msix'),
    [string] $WindowsSdkRoot = $env:WindowsSdkDir,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-ExistingFile([string] $Path, [string] $Description) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Resolve-MakeAppx([string] $SdkRoot) {
    $fromPath = Get-Command makeappx.exe -ErrorAction SilentlyContinue
    if ($fromPath) { return $fromPath.Source }
    if (-not $SdkRoot) {
        throw 'MakeAppx was not found. Pass -WindowsSdkRoot or set WindowsSdkDir.'
    }
    $candidate = Get-ChildItem -LiteralPath (Join-Path $SdkRoot 'bin') -Recurse -Filter makeappx.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '[\\/]x64[\\/]makeappx\.exe$' } |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if (-not $candidate) { throw "No x64 MakeAppx was found below $SdkRoot" }
    return $candidate.FullName
}

function Get-PeContract([string] $Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 256 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
        throw "Not a PE executable: $Path"
    }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($peOffset -lt 0 -or ($peOffset + 94) -ge $bytes.Length) {
        throw "Invalid PE header offset: $Path"
    }
    [pscustomobject]@{
        Machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
        Subsystem = [BitConverter]::ToUInt16($bytes, $peOffset + 92)
    }
}

function Assert-PeContract([string] $Path, [uint16] $Machine, [uint16] $Subsystem, [string] $Role) {
    $actual = Get-PeContract $Path
    if ($actual.Machine -ne $Machine) {
        throw ('{0} has PE machine 0x{1:X4}; expected 0x{2:X4}: {3}' -f $Role, $actual.Machine, $Machine, $Path)
    }
    if ($actual.Subsystem -ne $Subsystem) {
        throw "$Role has subsystem $($actual.Subsystem); expected $Subsystem`: $Path"
    }
}

function Write-Logo([string] $Source, [string] $Destination, [int] $Size) {
    Add-Type -AssemblyName System.Drawing
    $image = [Drawing.Image]::FromFile($Source)
    try {
        $bitmap = [Drawing.Bitmap]::new($Size, $Size)
        try {
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            try { $graphics.DrawImage($image, 0, 0, $Size, $Size) }
            finally { $graphics.Dispose() }
            $bitmap.Save($Destination, [Drawing.Imaging.ImageFormat]::Png)
        }
        finally { $bitmap.Dispose() }
    }
    finally { $image.Dispose() }
}

function Escape-Xml([string] $Value) {
    return [Security.SecurityElement]::Escape($Value)
}

function Assert-UnpackedPackage([string] $Directory, [string] $Architecture, [uint16] $Machine) {
    $manifestPath = Join-Path $Directory 'AppxManifest.xml'
    [xml] $manifest = Get-Content -Raw -LiteralPath $manifestPath
    $manager = [Xml.XmlNamespaceManager]::new($manifest.NameTable)
    $manager.AddNamespace('f', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
    $manager.AddNamespace('uap3', 'http://schemas.microsoft.com/appx/manifest/uap/windows10/3')
    $manager.AddNamespace('desktop', 'http://schemas.microsoft.com/appx/manifest/desktop/windows10')
    $manager.AddNamespace('rescap', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities')

    $identity = $manifest.SelectSingleNode('/f:Package/f:Identity', $manager)
    if ($identity.ProcessorArchitecture -ne $Architecture -or $identity.Version -ne $Version) {
        throw "Unexpected manifest architecture or version in $manifestPath"
    }
    $aliasExtension = $manifest.SelectSingleNode('//uap3:Extension[@Category="windows.appExecutionAlias"]', $manager)
    $alias = $manifest.SelectSingleNode('//desktop:ExecutionAlias', $manager)
    if ($aliasExtension.Executable -ne 'lokalite-cli.exe' -or $alias.Alias -ne 'lokalite.exe') {
        throw "The execution alias does not target lokalite-cli.exe in $manifestPath"
    }
    $startup = $manifest.SelectSingleNode('//desktop:StartupTask', $manager)
    if (-not $startup -or $startup.Enabled -ne 'false') {
        throw "The packaged startup task must default to disabled in $manifestPath"
    }
    $capabilities = @($manifest.SelectNodes('//f:Capabilities/*', $manager))
    if ($capabilities.Count -ne 1 -or $capabilities[0].LocalName -ne 'Capability' -or $capabilities[0].GetAttribute('Name') -ne 'runFullTrust') {
        throw "The package must declare only runFullTrust in $manifestPath"
    }
    Assert-PeContract (Join-Path $Directory 'Lokalite.exe') $Machine 2 "$Architecture desktop"
    Assert-PeContract (Join-Path $Directory 'lokalite-cli.exe') $Machine 3 "$Architecture CLI"
}

$desktopInputs = @{ x64 = Resolve-ExistingFile $DesktopX64 'x64 desktop executable'; arm64 = Resolve-ExistingFile $DesktopArm64 'ARM64 desktop executable' }
$cliInputs = @{ x64 = Resolve-ExistingFile $CliX64 'x64 CLI executable'; arm64 = Resolve-ExistingFile $CliArm64 'ARM64 CLI executable' }
$makeAppx = Resolve-MakeAppx $WindowsSdkRoot
$template = Resolve-ExistingFile (Join-Path $PSScriptRoot 'AppxManifest.xml.template') 'manifest template'
$logoSource = Resolve-ExistingFile (Join-Path $PSScriptRoot '..\..\assets\AppIcon.png') 'application icon'

if ($IdentityName -match '(__|TODO|PLACEHOLDER)') { throw 'Supply an explicit package identity; placeholders are not accepted.' }
if ($Publisher -match '(__|TODO|PLACEHOLDER)') { throw 'Supply an explicit Publisher; placeholders are not accepted.' }

$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
$buildRoot = Join-Path $outputRoot $Version
if (Test-Path -LiteralPath $buildRoot) {
    if (-not $Force) { throw "Output already exists: $buildRoot. Pass -Force to replace this exact version directory." }
    $resolvedRoot = [IO.Path]::GetFullPath($outputRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $resolvedBuild = [IO.Path]::GetFullPath($buildRoot)
    if (-not $resolvedBuild.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove output outside $outputRoot"
    }
    Remove-Item -LiteralPath $buildRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null

$packages = @()
foreach ($architecture in @('x64', 'arm64')) {
    $machine = if ($architecture -eq 'x64') { [uint16] 0x8664 } else { [uint16] 0xaa64 }
    Assert-PeContract $desktopInputs[$architecture] $machine 2 "$architecture desktop input"
    Assert-PeContract $cliInputs[$architecture] $machine 3 "$architecture CLI input"

    $layout = Join-Path $buildRoot "layout-$architecture"
    $assets = Join-Path $layout 'Assets'
    New-Item -ItemType Directory -Path $assets -Force | Out-Null
    Copy-Item -LiteralPath $desktopInputs[$architecture] -Destination (Join-Path $layout 'Lokalite.exe')
    Copy-Item -LiteralPath $cliInputs[$architecture] -Destination (Join-Path $layout 'lokalite-cli.exe')
    Write-Logo $logoSource (Join-Path $assets 'StoreLogo.png') 50
    Write-Logo $logoSource (Join-Path $assets 'Square150x150Logo.png') 150
    Write-Logo $logoSource (Join-Path $assets 'Square44x44Logo.png') 44

    $rendered = [IO.File]::ReadAllText($template)
    $rendered = $rendered.Replace('__IDENTITY_NAME__', (Escape-Xml $IdentityName))
    $rendered = $rendered.Replace('__PUBLISHER__', (Escape-Xml $Publisher))
    $rendered = $rendered.Replace('__PUBLISHER_DISPLAY_NAME__', (Escape-Xml $PublisherDisplayName))
    $rendered = $rendered.Replace('__VERSION__', $Version).Replace('__ARCHITECTURE__', $architecture)
    [IO.File]::WriteAllText((Join-Path $layout 'AppxManifest.xml'), $rendered, [Text.UTF8Encoding]::new($false))

    $package = Join-Path $buildRoot "Lokalite_${Version}_${architecture}.msix"
    & $makeAppx pack /o /d $layout /p $package
    if ($LASTEXITCODE -ne 0) { throw "MakeAppx pack failed for $architecture" }
    $unpacked = Join-Path $buildRoot "unpacked-$architecture"
    & $makeAppx unpack /p $package /d $unpacked
    if ($LASTEXITCODE -ne 0) { throw "MakeAppx unpack failed for $architecture" }
    Assert-UnpackedPackage $unpacked $architecture $machine
    foreach ($payload in @('Lokalite.exe', 'lokalite-cli.exe')) {
        $stagedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $layout $payload)).Hash
        $unpackedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $unpacked $payload)).Hash
        if ($stagedHash -ne $unpackedHash) { throw "$payload changed during $architecture packaging" }
    }
    $packages += $package
}

$bundleInput = Join-Path $buildRoot 'bundle-input'
New-Item -ItemType Directory -Path $bundleInput | Out-Null
$packages | ForEach-Object { Copy-Item -LiteralPath $_ -Destination $bundleInput }
$bundle = Join-Path $buildRoot "Lokalite_${Version}.msixbundle"
& $makeAppx bundle /o /d $bundleInput /p $bundle /bv $Version
if ($LASTEXITCODE -ne 0) { throw 'MakeAppx bundle failed' }
$unbundled = Join-Path $buildRoot 'unbundled'
& $makeAppx unbundle /p $bundle /d $unbundled
if ($LASTEXITCODE -ne 0) { throw 'MakeAppx unbundle failed' }

[xml] $bundleManifest = Get-Content -Raw -LiteralPath (Join-Path $unbundled 'AppxMetadata\AppxBundleManifest.xml')
$bundleManager = [Xml.XmlNamespaceManager]::new($bundleManifest.NameTable)
$bundleManager.AddNamespace('b', 'http://schemas.microsoft.com/appx/2013/bundle')
$bundlePackages = @($bundleManifest.SelectNodes('/b:Bundle/b:Packages/b:Package', $bundleManager))
$bundleArchitectures = @($bundlePackages | ForEach-Object { $_.GetAttribute('Architecture') } | Sort-Object)
if ($bundlePackages.Count -ne 2 -or $bundleArchitectures -join ',' -ne 'arm64,x64') {
    throw 'Bundle does not contain exactly the x64 and ARM64 application packages.'
}
if ($bundleManifest.Bundle.Identity.Name -ne $IdentityName -or $bundleManifest.Bundle.Identity.Publisher -ne $Publisher -or $bundleManifest.Bundle.Identity.Version -ne $Version) {
    throw 'Bundle identity, Publisher, or version differs from the requested contract.'
}

$artifacts = $packages + $bundle
$checksumLines = $artifacts | ForEach-Object {
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $_
    "$($hash.Hash.ToLowerInvariant())  $(Split-Path $_ -Leaf)"
}
[IO.File]::WriteAllLines((Join-Path $buildRoot 'SHA256SUMS'), $checksumLines, [Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    Version = $Version
    IdentityName = $IdentityName
    Publisher = $Publisher
    Packages = $packages
    Bundle = $bundle
    Checksums = (Join-Path $buildRoot 'SHA256SUMS')
    StoreValidated = $false
}
