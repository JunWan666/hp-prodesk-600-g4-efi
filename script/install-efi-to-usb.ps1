param(
    [string]$DriveLetter,
    [string]$Source,
    [switch]$Yes,
    [switch]$AllowNonFat32,
    [switch]$NoBackup,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = $null
if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $candidateRoot = Join-Path $PSScriptRoot ".."
    if (Test-Path -LiteralPath (Join-Path $candidateRoot "all_efi") -PathType Container) {
        $repoRoot = (Resolve-Path -LiteralPath $candidateRoot).Path
    }
}

$coreUrl = "https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install-efi-to-usb-core.ps1"
$tempCore = $null

if ($repoRoot) {
    $localCore = Join-Path $repoRoot "script\install-efi-to-usb-core.ps1"
    if (Test-Path -LiteralPath $localCore -PathType Leaf) {
        $tempCore = $localCore
    }
}

if (-not $tempCore) {
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("hp-prodesk-usb-launcher-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $tempCore = Join-Path $tempDir "install-efi-to-usb-core.ps1"
    Invoke-WebRequest -Uri $coreUrl -OutFile $tempCore -UseBasicParsing
}

$coreParams = @{}
if (-not [string]::IsNullOrWhiteSpace($DriveLetter)) {
    $coreParams["DriveLetter"] = $DriveLetter
}
if (-not [string]::IsNullOrWhiteSpace($Source)) {
    $coreParams["Source"] = $Source
}
if ($Yes) { $coreParams["Yes"] = $true }
if ($AllowNonFat32) { $coreParams["AllowNonFat32"] = $true }
if ($NoBackup) { $coreParams["NoBackup"] = $true }
if ($Help) { $coreParams["Help"] = $true }

try {
    & $tempCore @coreParams
} finally {
    if ($tempCore -and -not $repoRoot) {
        $parent = Split-Path -Parent $tempCore
        if (Test-Path -LiteralPath $parent) {
            Remove-Item -LiteralPath $parent -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
