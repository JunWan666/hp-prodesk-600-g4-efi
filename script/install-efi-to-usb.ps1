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
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("hpoc-l-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $tempCore = Join-Path $tempDir "install-efi-to-usb-core.ps1"
    $coreDownloadUrl = $coreUrl + "?cacheBust=" + [System.Guid]::NewGuid().ToString("N")
    $headers = @{
        "Cache-Control" = "no-cache"
        "Pragma" = "no-cache"
    }
    $oldProgressPreference = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    try {
        try {
            Invoke-WebRequest -Uri $coreDownloadUrl -OutFile $tempCore -UseBasicParsing -Headers $headers
        } catch {
            Invoke-WebRequest -Uri $coreUrl -OutFile $tempCore -UseBasicParsing -Headers $headers
        }
    } finally {
        $ProgressPreference = $oldProgressPreference
    }
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
