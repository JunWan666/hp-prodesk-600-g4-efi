param(
    [string]$DriveLetter,
    [string]$Source,
    [switch]$Yes,
    [switch]$AllowNonFat32,
    [switch]$NoBackup,
    [switch]$NoRecovery,
    [switch]$ForceRecovery,
    [switch]$FormatUsb,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Script:RepoRoot = $null
try {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $candidateRoot = Join-Path $PSScriptRoot ".."
        if (Test-Path -LiteralPath (Join-Path $candidateRoot "all_efi") -PathType Container) {
            $Script:RepoRoot = (Resolve-Path -LiteralPath $candidateRoot).Path
        }
    }
} catch {
    $Script:RepoRoot = $null
}

if (-not $Script:RepoRoot -and (Test-Path -LiteralPath (Join-Path $PWD.Path "all_efi") -PathType Container)) {
    $Script:RepoRoot = (Resolve-Path -LiteralPath $PWD.Path).Path
}

$Script:SelectedMode = ""
$Script:ReleaseTag = "v13.7.8"
$Script:RepoUrl = "https://github.com/JunWan666/hp-prodesk-600-g4-efi"
$Script:RawBaseUrl = "https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main"
$Script:RecoveryBoardId = "Mac-B4831CEBD52A0C4C"
$Script:RecoveryMlb = "00000000000000000"
$Script:RecoveryOsType = "latest"
$Script:TempDirs = @()
$Script:AnsiColorInitialized = $false
$Script:UseAnsiColor = $false
$Script:AnsiReset = "$([char]27)[0m"
$Script:AnsiColors = @{
    Blue = "$([char]27)[34m"
    Green = "$([char]27)[32m"
    Yellow = "$([char]27)[33m"
    Red = "$([char]27)[31m"
    DarkGray = "$([char]27)[90m"
    White = "$([char]27)[37m"
    Cyan = "$([char]27)[36m"
}

function Initialize-AnsiColor {
    if ($Script:AnsiColorInitialized) {
        return
    }

    $Script:AnsiColorInitialized = $true
    if ($env:NO_COLOR) {
        return
    }

    if ($env:WT_SESSION -or $env:TERM_PROGRAM -or ($env:TERM -match "xterm|ansi|vt100|color")) {
        $Script:UseAnsiColor = $true
        return
    }

    try {
        if (-not ("HpocConsoleMode" -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class HpocConsoleMode {
    [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out int lpMode);
    [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, int dwMode);
}
"@ -ErrorAction Stop
        }

        $handle = [HpocConsoleMode]::GetStdHandle(-11)
        $mode = 0
        if ([HpocConsoleMode]::GetConsoleMode($handle, [ref]$mode)) {
            $Script:UseAnsiColor = [HpocConsoleMode]::SetConsoleMode($handle, ($mode -bor 4))
        }
    } catch {
        $Script:UseAnsiColor = $false
    }
}

function Write-HostSafe {
    param(
        [AllowNull()][object]$Text = "",
        [string]$Color = ""
    )

    $message = if ($null -eq $Text) { "" } else { [string]$Text }
    Initialize-AnsiColor

    if ($Script:UseAnsiColor -and $Script:AnsiColors.ContainsKey($Color)) {
        $message = "{0}{1}{2}" -f $Script:AnsiColors[$Color], $message, $Script:AnsiReset
    }

    try {
        Write-Host $message
    } catch {
        [System.Console]::WriteLine($message)
    }
}

function Write-Line {
    param([string]$Text = "")
    Write-HostSafe $Text
}

function Write-Info {
    param([string]$Text)
    Write-HostSafe ("==> {0}" -f $Text) "Blue"
}

function Write-Ok {
    param([string]$Text)
    Write-HostSafe ("OK  {0}" -f $Text) "Green"
}

function Write-Warn {
    param([AllowNull()][object]$Text)
    Write-HostSafe ("!!  {0}" -f $Text) "Yellow"
}

function Start-FreshConsoleLine {
    try {
        if ([System.Console]::CursorLeft -gt 0) {
            [System.Console]::WriteLine()
        }
    } catch {
        return
    }
}

function Stop-WithError {
    param([string]$Text)
    Write-HostSafe ("错误：{0}" -f $Text) "Red"
    exit 1
}

function Write-Rule {
    Write-HostSafe "──────────────────────────────────────────────────────────────" "DarkGray"
}

function Write-Section {
    param([string]$Title)
    Write-Line
    Write-Rule
    Write-HostSafe "  $Title" "White"
    Write-Rule
}

function Show-Banner {
    Write-HostSafe "╭────────────────────────────────────────────────────────────╮" "Cyan"
    Write-HostSafe "│  HP ProDesk 600 G4 DM                                      │" "Cyan"
    Write-HostSafe "│  OpenCore EFI USB Installer                                │" "Cyan"
    Write-HostSafe "│  Windows · Ventura 13.7.8 · safe / igpu · DW1820A Ready    │" "Cyan"
    Write-HostSafe "╰────────────────────────────────────────────────────────────╯" "Cyan"
    Write-Line
}

function Show-Usage {
    $usage = @'
用法：
  irm https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install-efi-to-usb.ps1 | iex
  iex "& { $(irm https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install-efi-to-usb.ps1) } -DriveLetter E -Yes"
  powershell -ExecutionPolicy Bypass -File .\script\install-efi-to-usb.ps1
  powershell -ExecutionPolicy Bypass -File .\script\install-efi-to-usb.ps1 -DriveLetter E
  powershell -ExecutionPolicy Bypass -File .\script\install-efi-to-usb.ps1 -DriveLetter E -FormatUsb
  powershell -ExecutionPolicy Bypass -File .\script\install-efi-to-usb.ps1 -DriveLetter E -Source .\all_efi\igpu\13.7.8\EFI -Yes

说明：
  - 这个脚本用于在 Windows 上把 OpenCore EFI 和 macOS Recovery 安装到 U 盘。
  - 在线运行时会从 GitHub Release 下载 Ventura 13.7.8 igpu / safe EFI。
  - 如果 U 盘缺少 com.apple.recovery.boot，会从 Apple 下载 BaseSystem.dmg 和 BaseSystem.chunklist。
  - 本地 clone 仓库运行时，也可以选择本地 all_efi 目录里的 EFI。
  - 默认不会格式化 U 盘；交互选择格式化或传入 -FormatUsb 才会快速格式化目标盘符为 FAT32。
  - 已有 EFI\BOOT / EFI\OC 会先备份到 EFI\backup-before-opencore-时间。
  - EFI\APPLE 会保留。
  - -NoRecovery 只安装 EFI；-ForceRecovery 强制重新下载 Recovery。
  - 默认来源是 GitHub Ventura 13.7.8 igpu 核显加速版。
  - 目标 U 盘建议使用 FAT32；非 FAT32 默认会停止。
'@
    Write-HostSafe $usage
}

function Get-ReleaseSourceOptions {
    @(
        [pscustomobject]@{
            Index = 1
            Kind = "Release"
            Mode = "igpu"
            Name = "GitHub · Ventura 13.7.8 · igpu 核显加速版"
            FileName = "hp-prodesk-600-g4-dm-ventura-13.7.8-igpu.zip"
            Sha256 = "10b10e6c30f986c16f1e4cbbfef35cfe80cd2791d33d5881f4731a81cfa03f97"
            Desc = "DP 直连 / 主动式 DP 转 HDMI，日常使用推荐；包含 DW1820A"
        },
        [pscustomobject]@{
            Index = 2
            Kind = "Release"
            Mode = "safe"
            Name = "GitHub · Ventura 13.7.8 · safe 安全亮屏版"
            FileName = "hp-prodesk-600-g4-dm-ventura-13.7.8-safe.zip"
            Sha256 = "0232d1dba1a4b754cb3b8777ffb2c4ad4c5b7da8d51631c53fd6d4e8c9ba0fa4"
            Desc = "首次安装、黑屏救援、显示器线材不确定；包含 DW1820A"
        }
    )
}

function Get-LocalSourceOptions {
    if (-not $Script:RepoRoot) {
        return @()
    }

    @(
        [pscustomobject]@{
            Kind = "Local"
            Name = "本地 · Ventura 13.7.8 · igpu 核显加速版"
            Path = Join-Path $Script:RepoRoot "all_efi\igpu\13.7.8\EFI"
            Desc = "本地仓库文件；DP 直连 / 主动式 DP 转 HDMI"
        },
        [pscustomobject]@{
            Kind = "Local"
            Name = "本地 · Ventura 13.7.8 · safe 安全亮屏版"
            Path = Join-Path $Script:RepoRoot "all_efi\safe\13.7.8\EFI"
            Desc = "本地仓库文件；首次安装、黑屏救援"
        },
        [pscustomobject]@{
            Kind = "Local"
            Name = "本地 · Monterey 12.7.6 · igpu 核显加速版"
            Path = Join-Path $Script:RepoRoot "all_efi\igpu\12.7.6\EFI"
            Desc = "历史备用版本"
        },
        [pscustomobject]@{
            Kind = "Local"
            Name = "本地 · Monterey 12.7.6 · safe 安全亮屏版"
            Path = Join-Path $Script:RepoRoot "all_efi\safe\12.7.6\EFI"
            Desc = "历史备用 / 救援版本"
        }
    )
}

function Get-SourceOptions {
    $items = @()
    $items += Get-ReleaseSourceOptions
    $items += Get-LocalSourceOptions

    $index = 1
    foreach ($item in $items) {
        $item | Add-Member -NotePropertyName Index -NotePropertyValue $index -Force
        $index++
    }

    return $items
}

function Get-FullPathSafe {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $PWD.Path $Path))
}

function Test-EfiSource {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $full = Get-FullPathSafe $Path
    $boot = Join-Path $full "BOOT"
    $oc = Join-Path $full "OC"
    $config = Join-Path $oc "config.plist"

    return ((Test-Path -LiteralPath $boot -PathType Container) -and
            (Test-Path -LiteralPath $oc -PathType Container) -and
            (Test-Path -LiteralPath $config -PathType Leaf))
}

function Resolve-EfiSource {
    param([string]$Path)

    $full = Get-FullPathSafe $Path
    if (Test-EfiSource $full) {
        return (Resolve-Path -LiteralPath $full).Path
    }

    $nested = Join-Path $full "EFI"
    if (Test-EfiSource $nested) {
        return (Resolve-Path -LiteralPath $nested).Path
    }

    return $null
}

function New-WorkDir {
    $base = Join-Path ([System.IO.Path]::GetTempPath()) ("hpoc-e-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Path $base -Force | Out-Null
    $Script:TempDirs += $base
    return $base
}

function Clear-WorkDirs {
    foreach ($dir in $Script:TempDirs) {
        if (Test-Path -LiteralPath $dir) {
            try {
                Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Warn "临时目录清理失败，可手动删除：$dir"
            }
        }
    }
}

function Invoke-DownloadFile {
    param(
        [string]$Url,
        [string]$OutFile
    )

    $fileName = Split-Path -Leaf $OutFile
    $sourceName = if ($Url -like "$($Script:RepoUrl)*") { "GitHub Release" } else { "GitHub Raw 备用" }
    Write-Info ("下载 {0}：{1}" -f $sourceName, $fileName)

    $oldProgressPreference = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    } catch {
        throw "下载失败：$($_.Exception.Message)"
    } finally {
        $ProgressPreference = $oldProgressPreference
    }
}

function Get-CurlExePath {
    $candidates = @()
    if ($env:SystemRoot) {
        $candidates += (Join-Path $env:SystemRoot "System32\curl.exe")
        $candidates += (Join-Path $env:SystemRoot "Sysnative\curl.exe")
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    $command = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    return $null
}

function Assert-AppleDownloadLength {
    param(
        [string]$Path,
        [string]$FileName,
        [Nullable[Int64]]$ExpectedSize = $null,
        [Int64]$RemoteSize = -1
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw ("{0} 下载后没有找到文件。" -f $FileName)
    }

    $actual = (Get-Item -LiteralPath $Path).Length
    if ($ExpectedSize -and $actual -ne $ExpectedSize) {
        throw ("{0} 下载不完整：实际 {1:N1} MB，期望 {2:N1} MB" -f $FileName, ($actual / 1MB), ($ExpectedSize / 1MB))
    }

    if (-not $ExpectedSize -and $RemoteSize -gt 0 -and $actual -ne $RemoteSize) {
        throw ("{0} 下载不完整：实际 {1:N1} MB，远端 {2:N1} MB" -f $FileName, ($actual / 1MB), ($RemoteSize / 1MB))
    }

    return $actual
}

function Invoke-CurlAppleAssetDownload {
    param(
        [string]$Url,
        [string]$AssetToken,
        [string]$OutFile,
        [string]$FileName,
        [Nullable[Int64]]$ExpectedSize = $null
    )

    $curl = Get-CurlExePath
    if ([string]::IsNullOrWhiteSpace($curl)) {
        throw "没有找到 Windows 自带 curl.exe。"
    }

    if ($ExpectedSize -and $ExpectedSize -gt 1MB) {
        Invoke-CurlRangeAppleAssetDownload -Url $Url -AssetToken $AssetToken -OutFile $OutFile -FileName $FileName -ExpectedSize $ExpectedSize -CurlPath $curl
        return
    }

    Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
    $args = @(
        "-4",
        "-L",
        "--fail",
        "--retry", "3",
        "--retry-delay", "2",
        "--connect-timeout", "30",
        "--silent",
        "--show-error",
        "-A", "InternetRecovery/1.0",
        "-H", ("Cookie: AssetToken={0}" -f $AssetToken),
        "-o", $OutFile,
        $Url
    )

    & $curl @args
    if ($LASTEXITCODE -ne 0) {
        throw ("curl.exe 下载失败，退出代码：{0}" -f $LASTEXITCODE)
    }

    $actual = Assert-AppleDownloadLength -Path $OutFile -FileName $FileName -ExpectedSize $ExpectedSize
    if ($ExpectedSize) {
        Write-Ok ("{0} 下载完成：{1:N1} MB" -f $FileName, ($actual / 1MB))
    }
}

function Get-AppleCdnResolveSpecs {
    param([string]$Url)

    $uri = [Uri]$Url
    if ($uri.Scheme -ne "http") {
        return @()
    }

    $ips = @()
    try {
        $ips += [System.Net.Dns]::GetHostAddresses($uri.Host) |
            Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
            ForEach-Object { $_.IPAddressToString }
    } catch {
        $ips = @()
    }

    $resolveDns = Get-Command Resolve-DnsName -ErrorAction SilentlyContinue
    if ($resolveDns) {
        foreach ($dnsServer in @("1.1.1.1", "8.8.8.8")) {
            try {
                $ips += Resolve-DnsName -Name $uri.Host -Type A -Server $dnsServer -ErrorAction Stop |
                    Where-Object { $_.IP4Address } |
                    ForEach-Object { $_.IP4Address }
            } catch {
                continue
            }
        }
    }

    $resolveSpecs = @()
    foreach ($ip in @($ips | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        $resolveSpecs += ("{0}:80:{1}" -f $uri.Host, $ip)
    }

    return $resolveSpecs
}

function Invoke-CurlRangeSegmentDownload {
    param(
        [string]$Url,
        [string]$AssetToken,
        [string]$OutFile,
        [string]$Range,
        [string]$CurlPath,
        [Int64]$ExpectedSize,
        [string[]]$ResolveSpecs = @()
    )

    $baseArgs = @(
        "-4",
        "-L",
        "--fail",
        "--retry", "4",
        "--retry-delay", "1",
        "--retry-max-time", "60",
        "--connect-timeout", "30",
        "--silent",
        "--show-error",
        "-A", "InternetRecovery/1.0",
        "-H", ("Cookie: AssetToken={0}" -f $AssetToken),
        "-r", $Range,
        "-o", $OutFile,
        $Url
    )

    $lastError = ""
    $candidates = @($null) + @($ResolveSpecs)
    foreach ($resolveSpec in $candidates) {
        Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
        $errorFile = "{0}.curlerr" -f $OutFile
        Remove-Item -LiteralPath $errorFile -Force -ErrorAction SilentlyContinue
        $args = $baseArgs
        if (-not [string]::IsNullOrWhiteSpace($resolveSpec)) {
            $args = @("--resolve", $resolveSpec) + $baseArgs
        }

        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & $CurlPath @args 2> $errorFile
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $oldErrorActionPreference
        }

        $curlOutput = ""
        if (Test-Path -LiteralPath $errorFile -PathType Leaf) {
            $curlOutputText = Get-Content -LiteralPath $errorFile -Raw -ErrorAction SilentlyContinue
            if ($null -ne $curlOutputText) {
                $curlOutput = $curlOutputText.Trim()
            }
            Remove-Item -LiteralPath $errorFile -Force -ErrorAction SilentlyContinue
        }

        if ($exitCode -eq 0) {
            if (-not (Test-Path -LiteralPath $OutFile -PathType Leaf)) {
                $lastError = "未生成分段文件"
                continue
            }

            $actualSize = (Get-Item -LiteralPath $OutFile).Length
            if ($actualSize -eq $ExpectedSize) {
                return [pscustomobject]@{
                    Ok = $true
                    Error = ""
                }
            }

            $lastError = "分段大小不正确：实际 $actualSize 字节，期望 $ExpectedSize 字节"
            continue
        }

        $lastError = "curl.exe 退出代码：$exitCode"
        if (-not [string]::IsNullOrWhiteSpace($curlOutput)) {
            $lastError = "{0}；{1}" -f $lastError, $curlOutput
        }
    }

    return [pscustomobject]@{
        Ok = $false
        Error = $lastError
    }
}

function Invoke-CurlRangeAppleAssetDownload {
    param(
        [string]$Url,
        [string]$AssetToken,
        [string]$OutFile,
        [string]$FileName,
        [Int64]$ExpectedSize,
        [string]$CurlPath
    )

    Write-Info ("{0} 使用分段下载：每段 1.0 MB" -f $FileName)
    Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue

    $partFile = "{0}.part" -f $OutFile
    $segmentSize = [int64]1MB
    $done = [int64]0
    $lastPercent = -1
    $resolveSpecs = @(Get-AppleCdnResolveSpecs -Url $Url)
    $outputStream = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)

    try {
        while ($done -lt $ExpectedSize) {
            $remaining = $ExpectedSize - $done
            $currentSize = [int64][math]::Min($segmentSize, $remaining)
            $start = $done
            $end = $done + $currentSize - 1
            $range = "{0}-{1}" -f $start, $end
            $lastError = ""
            $segmentOk = $false

            for ($attempt = 1; $attempt -le 8; $attempt++) {
                $result = Invoke-CurlRangeSegmentDownload -Url $Url -AssetToken $AssetToken -OutFile $partFile -Range $range -CurlPath $CurlPath -ExpectedSize $currentSize -ResolveSpecs $resolveSpecs
                if ($result.Ok) {
                    $segmentOk = $true
                    break
                }

                $lastError = $result.Error
                if ($attempt -lt 8) {
                    Start-Sleep -Seconds ([math]::Min(10, $attempt * 2))
                }
            }

            if (-not $segmentOk) {
                throw ("{0} 分段下载失败：bytes {1}。{2}" -f $FileName, $range, $lastError)
            }

            $inputStream = [System.IO.File]::OpenRead($partFile)
            try {
                $inputStream.CopyTo($outputStream)
            } finally {
                $inputStream.Close()
            }

            $done += $currentSize
            $percent = [int][math]::Floor(($done * 100.0) / $ExpectedSize)
            if ($percent -ge 100 -or $percent -ge ($lastPercent + 10)) {
                $lastPercent = $percent
                Write-Info ("{0} 下载进度：{1:N1} / {2:N1} MB ({3}%)" -f $FileName, ($done / 1MB), ($ExpectedSize / 1MB), $percent)
            }
        }
    } finally {
        $outputStream.Close()
        Remove-Item -LiteralPath $partFile -Force -ErrorAction SilentlyContinue
    }

    $actual = Assert-AppleDownloadLength -Path $OutFile -FileName $FileName -ExpectedSize $ExpectedSize
    Write-Ok ("{0} 下载完成：{1:N1} MB" -f $FileName, ($actual / 1MB))
}

function Invoke-WebAppleAssetDownload {
    param(
        [string]$Url,
        [string]$AssetToken,
        [string]$OutFile,
        [string]$FileName,
        [Nullable[Int64]]$ExpectedSize = $null
    )

    $uri = [Uri]$Url
    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = "GET"
    $request.UserAgent = "InternetRecovery/1.0"
    $request.KeepAlive = $false
    $request.Host = $uri.Host
    $request.Headers.Add("Cookie", ("AssetToken={0}" -f $AssetToken))

    $response = $request.GetResponse()
    try {
        $total = $response.ContentLength
        if ($ExpectedSize -and $total -gt 0 -and $total -ne $ExpectedSize) {
            Write-Warn ("{0} 远端大小与 chunklist 不一致：远端 {1:N1} MB，期望 {2:N1} MB" -f $FileName, ($total / 1MB), ($ExpectedSize / 1MB))
        }
        $inputStream = $response.GetResponseStream()
        $outputStream = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $done = [int64]0
        try {
            $buffer = New-Object byte[] (1024 * 1024)
            $lastPercent = -1

            while ($true) {
                $read = $inputStream.Read($buffer, 0, $buffer.Length)
                if ($read -le 0) {
                    break
                }

                $outputStream.Write($buffer, 0, $read)
                $done += $read

                if ($total -gt 0) {
                    $percent = [int][math]::Floor(($done * 100.0) / $total)
                    if ($percent -ge 100 -or $percent -ge ($lastPercent + 10)) {
                        $lastPercent = $percent
                        Write-Info ("{0} 下载进度：{1:N1} / {2:N1} MB ({3}%)" -f $FileName, ($done / 1MB), ($total / 1MB), $percent)
                    }
                }
            }
        } finally {
            $outputStream.Close()
            $inputStream.Close()
        }

        Assert-AppleDownloadLength -Path $OutFile -FileName $FileName -ExpectedSize $ExpectedSize -RemoteSize $total | Out-Null
    } finally {
        $response.Close()
    }
}

function New-HexString {
    param([int]$Length)

    -join (1..$Length | ForEach-Object { "{0:X}" -f (Get-Random -Minimum 0 -Maximum 16) })
}

function Invoke-AppleRecoveryRequest {
    param(
        [string]$Url,
        [string]$Method = "GET",
        [string]$Body = "",
        [string]$Cookie = ""
    )

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = $Method
    $request.UserAgent = "InternetRecovery/1.0"
    $request.KeepAlive = $false
    $request.Host = ([Uri]$Url).Host

    if (-not [string]::IsNullOrWhiteSpace($Cookie)) {
        $request.Headers.Add("Cookie", $Cookie)
    }

    if ($Method -eq "POST") {
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($Body)
        $request.ContentType = "text/plain"
        $request.ContentLength = $bytes.Length
        $stream = $request.GetRequestStream()
        try {
            $stream.Write($bytes, 0, $bytes.Length)
        } finally {
            $stream.Close()
        }
    }

    $response = $request.GetResponse()
    try {
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream(), [System.Text.Encoding]::ASCII)
        [pscustomobject]@{
            Headers = $response.Headers
            Body = $reader.ReadToEnd()
            StatusCode = [int]$response.StatusCode
        }
    } finally {
        $response.Close()
    }
}

function Get-AppleRecoveryInfo {
    Write-Info "查询 Apple Recovery：Ventura 13.7.8"

    try {
        $sessionResponse = Invoke-AppleRecoveryRequest -Url "http://osrecovery.apple.com/"
        $sessionCookie = ($sessionResponse.Headers["Set-Cookie"] -split "; " |
            Where-Object { $_ -like "session=*" } |
            Select-Object -First 1)

        if ([string]::IsNullOrWhiteSpace($sessionCookie)) {
            throw "Apple Recovery 没有返回 session cookie。"
        }

        $post = [ordered]@{
            cid = New-HexString 16
            sn = $Script:RecoveryMlb
            bid = $Script:RecoveryBoardId
            k = New-HexString 64
            fg = New-HexString 64
            os = $Script:RecoveryOsType
        }
        $body = ($post.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "`n"

        $imageResponse = Invoke-AppleRecoveryRequest `
            -Url "http://osrecovery.apple.com/InstallationPayload/RecoveryImage" `
            -Method "POST" `
            -Body $body `
            -Cookie $sessionCookie

        $info = @{}
        foreach ($line in ($imageResponse.Body -split "`n")) {
            if ($line -match "^([^:]+):\s*(.+)$") {
                $info[$matches[1]] = $matches[2].Trim()
            }
        }

        foreach ($key in @("AP", "AU", "AH", "AT", "CU", "CH", "CT")) {
            if (-not $info.ContainsKey($key)) {
                throw "Apple Recovery 响应缺少字段：$key"
            }
        }

        return [pscustomobject]@{
            Product = $info["AP"]
            DmgUrl = $info["AU"]
            DmgSha256 = $info["AH"].ToLowerInvariant()
            DmgToken = $info["AT"]
            ChunklistUrl = $info["CU"]
            ChunklistSha256 = $info["CH"].ToLowerInvariant()
            ChunklistToken = $info["CT"]
        }
    } catch {
        throw "Apple Recovery 查询失败：$($_.Exception.Message)"
    }
}

function Invoke-AppleAssetDownload {
    param(
        [string]$Url,
        [string]$AssetToken,
        [string]$OutFile,
        [string]$Label,
        [Nullable[Int64]]$ExpectedSize = $null
    )

    $fileName = Split-Path -Leaf $OutFile
    Write-Info ("下载 {0}：{1}" -f $Label, $fileName)

    try {
        Invoke-CurlAppleAssetDownload -Url $Url -AssetToken $AssetToken -OutFile $OutFile -FileName $fileName -ExpectedSize $ExpectedSize
    } catch {
        $curlError = $_.Exception.Message
        if ($ExpectedSize -and $ExpectedSize -gt 1MB) {
            throw $curlError
        }

        Write-Warn ("curl.exe 下载未成功，改用 PowerShell 流式下载：{0}" -f $curlError)
        Invoke-WebAppleAssetDownload -Url $Url -AssetToken $AssetToken -OutFile $OutFile -FileName $fileName -ExpectedSize $ExpectedSize
    }
}

function Invoke-AppleAssetDownloadWithRetry {
    param(
        [string]$Url,
        [string]$AssetToken,
        [string]$OutFile,
        [string]$Label,
        [Nullable[Int64]]$ExpectedSize = $null,
        [int]$MaxAttempts = 3
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            if ($attempt -gt 1) {
                Write-Warn ("重试下载 {0}（第 {1}/{2} 次）" -f (Split-Path -Leaf $OutFile), $attempt, $MaxAttempts)
            }
            Invoke-AppleAssetDownload -Url $Url -AssetToken $AssetToken -OutFile $OutFile -Label $Label -ExpectedSize $ExpectedSize
            return
        } catch {
            Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            if ($attempt -ge $MaxAttempts) {
                throw
            }
            Write-Warn $_.Exception.Message
            Start-Sleep -Seconds ([math]::Min(10, 2 * $attempt))
        }
    }
}

function Assert-FileSha256 {
    param(
        [string]$Path,
        [string]$ExpectedSha256,
        [string]$Label
    )

    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "$Label SHA256 校验失败。期望：$ExpectedSha256，实际：$actual"
    }

    Write-Ok "$Label SHA256 校验通过"
}

function Get-ChunklistEntries {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 36) {
        throw "chunklist 文件太小：$Path"
    }

    $magic = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4)
    $headerSize = [System.BitConverter]::ToUInt32($bytes, 4)
    $fileVersion = $bytes[8]
    $chunkMethod = $bytes[9]
    $chunkCount = [System.BitConverter]::ToUInt64($bytes, 12)
    $chunkOffset = [System.BitConverter]::ToUInt64($bytes, 20)
    $signatureOffset = [System.BitConverter]::ToUInt64($bytes, 28)

    if ($magic -ne "CNKL") {
        throw "chunklist magic 不正确。"
    }
    if ($headerSize -ne 36 -or $fileVersion -ne 1 -or $chunkMethod -ne 1) {
        throw "chunklist 格式不受支持。"
    }
    if ($chunkOffset -ne 36) {
        throw "chunklist chunk offset 不正确。"
    }
    if ($signatureOffset -ne ($chunkOffset + 36 * $chunkCount)) {
        throw "chunklist signature offset 不正确。"
    }
    if ($bytes.Length -lt $signatureOffset) {
        throw "chunklist 文件不完整。"
    }

    $entries = @()
    $offset = [int]$chunkOffset
    for ($i = 0; $i -lt $chunkCount; $i++) {
        $size = [System.BitConverter]::ToUInt32($bytes, $offset)
        $hashBytes = New-Object byte[] 32
        [System.Array]::Copy($bytes, $offset + 4, $hashBytes, 0, 32)
        $entries += [pscustomobject]@{
            Size = [int]$size
            Hash = ([System.BitConverter]::ToString($hashBytes) -replace "-", "").ToLowerInvariant()
        }
        $offset += 36
    }

    return $entries
}

function Read-ExactBytes {
    param(
        [System.IO.Stream]$Stream,
        [int]$Size
    )

    $buffer = New-Object byte[] $Size
    $offset = 0
    while ($offset -lt $Size) {
        $read = $Stream.Read($buffer, $offset, $Size - $offset)
        if ($read -le 0) {
            break
        }
        $offset += $read
    }

    if ($offset -ne $Size) {
        return $null
    }

    return $buffer
}

function Assert-RecoveryImageWithChunklist {
    param(
        [string]$DmgPath,
        [string]$ChunklistPath
    )

    Write-Info "校验 BaseSystem.dmg：按 chunklist 逐块验证"
    $entries = @(Get-ChunklistEntries -Path $ChunklistPath)
    if ($entries.Count -eq 0) {
        throw "chunklist 没有可校验的 chunk。"
    }

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($DmgPath)
    try {
        $total = ($entries | Measure-Object -Property Size -Sum).Sum
        $done = [int64]0
        $lastPercent = -1

        for ($i = 0; $i -lt $entries.Count; $i++) {
            $entry = $entries[$i]
            $chunk = Read-ExactBytes -Stream $stream -Size $entry.Size
            if ($null -eq $chunk) {
                throw "BaseSystem.dmg 不完整：chunk $($i + 1) 读取失败。"
            }

            $actual = ([System.BitConverter]::ToString($sha256.ComputeHash($chunk)) -replace "-", "").ToLowerInvariant()
            if ($actual -ne $entry.Hash) {
                throw "BaseSystem.dmg 校验失败：chunk $($i + 1) hash 不匹配。"
            }

            $done += $entry.Size
            if ($total -gt 0) {
                $percent = [int][math]::Floor(($done * 100.0) / $total)
                if ($percent -ge 100 -or $percent -ge ($lastPercent + 20)) {
                    $lastPercent = $percent
                    Write-Info ("校验进度：{0:N1} / {1:N1} MB ({2}%)" -f ($done / 1MB), ($total / 1MB), $percent)
                }
            }
        }

        if ($stream.ReadByte() -ne -1) {
            throw "BaseSystem.dmg 比 chunklist 描述更大，文件可能不匹配。"
        }
    } finally {
        $stream.Close()
        $sha256.Dispose()
    }

    Write-Ok "BaseSystem.dmg chunklist 校验通过"
}

function Get-ChunklistTotalSize {
    param([array]$Entries)

    return [int64](($Entries | Measure-Object -Property Size -Sum).Sum)
}

function Expand-ZipSafe {
    param(
        [string]$ZipPath,
        [string]$Destination
    )

    try {
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $Destination -Force
    } catch {
        throw "ZIP 解压失败：$($_.Exception.Message)"
    }
}

function Resolve-ExtractedEfi {
    param([string]$ExtractDir)

    $direct = Join-Path $ExtractDir "EFI"
    $resolved = Resolve-EfiSource $direct
    if ($resolved) {
        return $resolved
    }

    $candidates = @(Get-ChildItem -LiteralPath $ExtractDir -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq "EFI" })

    foreach ($candidate in $candidates) {
        $resolvedCandidate = Resolve-EfiSource $candidate.FullName
        if ($resolvedCandidate) {
            return $resolvedCandidate
        }
    }

    return $null
}

function Get-ReleaseAssetUrl {
    param([string]$FileName)
    return "$($Script:RepoUrl)/releases/download/$($Script:ReleaseTag)/$FileName"
}

function Get-RawAssetUrl {
    param([string]$FileName)
    return "$($Script:RawBaseUrl)/dist/$FileName"
}

function Download-ReleaseEfi {
    param([object]$Option)

    $workDir = New-WorkDir
    $zipPath = Join-Path $workDir $Option.FileName
    $extractDir = Join-Path $workDir "extract"
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

    $urls = @(
        (Get-ReleaseAssetUrl -FileName $Option.FileName)
        (Get-RawAssetUrl -FileName $Option.FileName)
    )

    $downloaded = $false
    foreach ($url in $urls) {
        try {
            Invoke-DownloadFile -Url $url -OutFile $zipPath
            $downloaded = $true
            break
        } catch {
            Write-Warn $_.Exception.Message
        }
    }

    if (-not $downloaded) {
        Stop-WithError "无法下载 $($Option.FileName)。请检查网络，或手动下载 Release ZIP。"
    }

    $actualHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = $Option.Sha256.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        Stop-WithError "SHA256 校验失败。期望：$expectedHash，实际：$actualHash"
    }
    Write-Ok "SHA256 校验通过"

    Expand-ZipSafe -ZipPath $zipPath -Destination $extractDir

    $resolved = Resolve-ExtractedEfi $extractDir
    if (-not $resolved) {
        Stop-WithError "解压后没有找到完整 EFI。需要包含 EFI\BOOT、EFI\OC 和 EFI\OC\config.plist。"
    }

    Write-Ok "已准备 EFI：$resolved"
    return $resolved
}

function Select-EfiSource {
    if (-not [string]::IsNullOrWhiteSpace($Source)) {
        $resolved = Resolve-EfiSource $Source
        if (-not $resolved) {
            Stop-WithError "指定的来源 EFI 不完整：$Source。需要包含 BOOT、OC 和 OC\config.plist。"
        }
        $Script:SelectedMode = "手动指定 EFI"
        return $resolved
    }

    while ($true) {
        Write-Section "选择 EFI 来源"
        $options = @(Get-SourceOptions)
        foreach ($option in $options) {
            $suffix = if ($option.Index -eq 1) { " [默认]" } else { "" }
            Write-HostSafe ("  {0}. {1}{2}" -f $option.Index, $option.Name, $suffix) "Green"
            Write-HostSafe ("     {0}" -f $option.Desc)
            if ($option.Kind -eq "Release") {
                Write-HostSafe ("     文件：{0}" -f $option.FileName) "DarkGray"
            } else {
                Write-HostSafe ("     路径：{0}" -f $option.Path) "DarkGray"
            }
            Write-Line
        }
        $manualIndex = $options.Count + 1
        Write-HostSafe ("  {0}. 手动输入 EFI 路径" -f $manualIndex)
        Write-HostSafe "  0. 退出"
        Write-Line

        $choice = Read-Host "请选择 EFI 来源 [1]"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = "1"
        }

        if ($choice -eq "0") {
            Write-Line "已退出，没有修改 U 盘。"
            exit 0
        }

        if ($choice -eq "$manualIndex") {
            $manual = Read-Host "请输入 EFI 路径"
            $resolvedManual = Resolve-EfiSource $manual
            if ($resolvedManual) {
                $Script:SelectedMode = "手动指定 EFI"
                return $resolvedManual
            }
            Write-Warn "这个路径不是完整 EFI，请确认里面有 BOOT 和 OC。"
            continue
        }

        if ($choice -notmatch "^\d+$") {
            Write-Warn "请输入序号。"
            continue
        }

        $selected = $options | Where-Object { $_.Index -eq [int]$choice } | Select-Object -First 1
        if (-not $selected) {
            Write-Warn "无效选择：$choice"
            continue
        }

        if ($selected.Kind -eq "Release") {
            $Script:SelectedMode = $selected.Name
            return (Download-ReleaseEfi $selected)
        }

        $resolved = Resolve-EfiSource $selected.Path
        if ($resolved) {
            $Script:SelectedMode = $selected.Name
            return $resolved
        }

        Write-Warn "来源 EFI 不完整：$($selected.Path)"
    }
}

function Convert-Size {
    param([Nullable[UInt64]]$Bytes)

    if (-not $Bytes) {
        return "-"
    }

    if ($Bytes -ge 1GB) {
        return "{0:N1} GB" -f ($Bytes / 1GB)
    }

    return "{0:N0} MB" -f ($Bytes / 1MB)
}

function Get-UsbDrives {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 2" |
        Where-Object { $_.DeviceID -match "^[A-Z]:" } |
        Sort-Object DeviceID
}

function Normalize-DriveLetter {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $letter = $Value.Trim().TrimEnd("\")
    if ($letter -match "^[A-Za-z]$") {
        return ($letter.ToUpperInvariant() + ":")
    }

    if ($letter -match "^[A-Za-z]:$") {
        return $letter.ToUpperInvariant()
    }

    Stop-WithError "盘符格式不正确：$Value。示例：E 或 E:"
}

function Get-DriveByLetter {
    param([string]$Letter)

    $normalized = Normalize-DriveLetter $Letter
    Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID = '{0}'" -f $normalized.Replace("'", "''"))
}

function Select-UsbDrive {
    if (-not [string]::IsNullOrWhiteSpace($DriveLetter)) {
        $drive = Get-DriveByLetter $DriveLetter
        if (-not $drive) {
            Stop-WithError "没有找到盘符：$DriveLetter"
        }
        if ($drive.DriveType -ne 2) {
            Stop-WithError "$($drive.DeviceID) 不是可移动磁盘。为了安全，脚本不会写入内置硬盘或外置硬盘。"
        }
        return $drive
    }

    $drives = @(Get-UsbDrives)
    if ($drives.Count -eq 0) {
        Stop-WithError "没有检测到带盘符的 U 盘。请插入 U 盘，或确认 EFI 分区已经在 Windows 里分配盘符。"
    }

    while ($true) {
        Write-Section "选择目标 U 盘"
        for ($i = 0; $i -lt $drives.Count; $i++) {
            $drive = $drives[$i]
            $index = $i + 1
            $label = if ($drive.VolumeName) { $drive.VolumeName } else { "无卷标" }
            $fs = if ($drive.FileSystem) { $drive.FileSystem } else { "未知格式" }
            $size = Convert-Size $drive.Size
            $free = Convert-Size $drive.FreeSpace
            $suffix = if ($index -eq 1) { " [默认]" } else { "" }
            Write-HostSafe ("  {0}. {1}\  {2}  {3}  总计 {4}  可用 {5}{6}" -f $index, $drive.DeviceID, $label, $fs, $size, $free, $suffix)
        }
        Write-HostSafe "  0. 退出"
        Write-Line

        $choice = Read-Host "请选择目标 U 盘 [1]"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = "1"
        }

        if ($choice -eq "0") {
            Write-Line "已退出，没有修改 U 盘。"
            exit 0
        }

        if ($choice -notmatch "^\d+$") {
            Write-Warn "请输入序号。"
            continue
        }

        $number = [int]$choice
        if ($number -lt 1 -or $number -gt $drives.Count) {
            Write-Warn "无效选择：$choice"
            continue
        }

        return $drives[$number - 1]
    }
}

function Test-Fat32Target {
    param([object]$Drive)

    if ($Drive.FileSystem -eq "FAT32") {
        return
    }

    if ($AllowNonFat32) {
        Write-Warn "$($Drive.DeviceID) 当前格式是 $($Drive.FileSystem)，不是 FAT32。你指定了 -AllowNonFat32，脚本会继续。"
        return
    }

    Stop-WithError "$($Drive.DeviceID) 当前格式是 $($Drive.FileSystem)，不是 FAT32。OpenCore UEFI 启动盘建议使用 FAT32，请先格式化或给 EFI 分区分配盘符。"
}

function Select-FormatMode {
    param([object]$Drive)

    if ($FormatUsb) {
        return $true
    }

    Write-Section "是否格式化 U 盘"
    Write-HostSafe ("  目标 U 盘：{0}\  {1}  {2}" -f $Drive.DeviceID, $Drive.VolumeName, $Drive.FileSystem)
    Write-Line
    Write-HostSafe "  1. 不格式化，只更新 EFI / Recovery [默认]"
    Write-HostSafe "  2. 格式化为 FAT32 / OPENCORE，然后安装"
    Write-HostSafe "  0. 退出"
    Write-Line

    while ($true) {
        $choice = Read-Host "请选择 [1]"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = "1"
        }

        if ($choice -eq "0") {
            Write-Line "已退出，没有修改 U 盘。"
            exit 0
        }

        if ($choice -eq "1") {
            return $false
        }

        if ($choice -eq "2") {
            return $true
        }

        Write-Warn "无效选择：$choice"
    }
}

function Format-UsbDrive {
    param([object]$Drive)

    if ($Drive.DriveType -ne 2) {
        Stop-WithError "$($Drive.DeviceID) 不是可移动磁盘，拒绝格式化。"
    }

    Write-Section "格式化确认"
    Write-Warn ("即将格式化 {0}\  {1}  {2}  总计 {3}" -f $Drive.DeviceID, $Drive.VolumeName, $Drive.FileSystem, (Convert-Size $Drive.Size))
    Write-Warn "这会删除该盘符上的所有文件。"
    Write-Line

    $confirm = Read-Host "如确认继续，请输入 YES"
    $confirm = if ($null -eq $confirm) { "" } else { $confirm.Trim() }
    $expected = "YES"
    if ($confirm -ne $expected) {
        Write-Line "确认文字不匹配，已取消格式化。"
        exit 0
    }

    Write-Info ("格式化 {0} 为 FAT32 / OPENCORE" -f $Drive.DeviceID)
    $letter = $Drive.DeviceID.TrimEnd(":")
    $formatErrors = @()
    $formatted = $false

    try {
        $partition = Get-Partition -DriveLetter $letter -ErrorAction Stop
        Format-Volume -Partition $partition -FileSystem FAT32 -NewFileSystemLabel "OPENCORE" -Force -Confirm:$false | Out-Null
        $formatted = $true
    } catch {
        $formatErrors += "Storage 模块：$($_.Exception.Message)"
    }

    if (-not $formatted) {
        try {
            $escapedDeviceId = $Drive.DeviceID.Replace("'", "''")
            $volume = Get-CimInstance Win32_Volume -Filter ("DriveLetter = '{0}'" -f $escapedDeviceId) -ErrorAction Stop |
                Select-Object -First 1

            if (-not $volume) {
                throw "没有找到 Win32_Volume：$($Drive.DeviceID)"
            }

            $result = Invoke-CimMethod -InputObject $volume -MethodName Format -Arguments @{
                FileSystem = "FAT32"
                QuickFormat = $true
                Label = "OPENCORE"
                EnableCompression = $false
            } -ErrorAction Stop

            if ($result.ReturnValue -ne 0) {
                throw "Win32_Volume.Format 返回代码：$($result.ReturnValue)"
            }

            $formatted = $true
        } catch {
            $formatErrors += "WMI Win32_Volume：$($_.Exception.Message)"
        }
    }

    if (-not $formatted) {
        try {
            $formatExe = Join-Path $env:SystemRoot "System32\format.com"
            if (-not (Test-Path -LiteralPath $formatExe -PathType Leaf)) {
                $formatExe = "format.com"
            }

            $output = & $formatExe $Drive.DeviceID "/FS:FAT32" "/V:OPENCORE" "/Q" "/X" "/Y" 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw (($output | Out-String).Trim())
            }

            $formatted = $true
        } catch {
            $formatErrors += "format.com：$($_.Exception.Message)"
        }
    }

    if (-not $formatted) {
        Stop-WithError ("格式化失败。{0}" -f ($formatErrors -join "；"))
    }

    Start-Sleep -Seconds 2
    $refreshed = Get-DriveByLetter $Drive.DeviceID
    if (-not $refreshed) {
        Stop-WithError "格式化后无法重新识别盘符：$($Drive.DeviceID)"
    }

    Write-Ok ("格式化完成：{0}\  {1}  {2}" -f $refreshed.DeviceID, $refreshed.VolumeName, $refreshed.FileSystem)
    return $refreshed
}

function Get-DriveRoot {
    param([object]$Drive)
    return ($Drive.DeviceID + "\")
}

function Get-RecoveryBootPath {
    param([object]$Drive)
    return (Join-Path (Get-DriveRoot $Drive) "com.apple.recovery.boot")
}

function Test-RecoveryBootComplete {
    param([object]$Drive)

    $path = Get-RecoveryBootPath $Drive
    $dmg = Join-Path $path "BaseSystem.dmg"
    $chunklist = Join-Path $path "BaseSystem.chunklist"

    if (-not ((Test-Path -LiteralPath $dmg -PathType Leaf) -and
              (Test-Path -LiteralPath $chunklist -PathType Leaf))) {
        return $false
    }

    try {
        $entries = @(Get-ChunklistEntries -Path $chunklist)
        if ($entries.Count -eq 0) {
            return $false
        }

        $expectedDmgSize = Get-ChunklistTotalSize -Entries $entries
        return ((Get-Item -LiteralPath $dmg).Length -eq $expectedDmgSize)
    } catch {
        return $false
    }
}

function Assert-UnderRoot {
    param(
        [string]$Path,
        [string]$Root
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root)
    $pathFull = [System.IO.Path]::GetFullPath($Path)

    if (-not $rootFull.EndsWith("\")) {
        $rootFull += "\"
    }

    if (-not $pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Stop-WithError "目标路径不在 U 盘内，已停止：$pathFull"
    }
}

function Confirm-Install {
    param(
        [object]$Drive,
        [string]$SourcePath,
        [bool]$WillFormat = $false
    )

    if ($Yes) {
        return
    }

    Write-Section "安装确认"
    Write-HostSafe ("  目标 U 盘：{0}\  {1}  {2}" -f $Drive.DeviceID, $Drive.VolumeName, $Drive.FileSystem)
    Write-HostSafe ("  来源 EFI ：{0}" -f $SourcePath)
    Write-HostSafe ("  模式     ：{0}" -f $Script:SelectedMode)
    if ($WillFormat) {
        Write-HostSafe "  格式化   ：已完成 FAT32 / OPENCORE"
    } else {
        Write-HostSafe "  格式化   ：不格式化"
    }
    if ($NoRecovery) {
        Write-HostSafe "  Recovery ：跳过（-NoRecovery）"
    } elseif ($ForceRecovery) {
        Write-HostSafe "  Recovery ：强制重新下载 macOS Recovery"
    } elseif (Test-RecoveryBootComplete $Drive) {
        Write-HostSafe "  Recovery ：已存在，保留"
    } else {
        Write-HostSafe "  Recovery ：缺失，将从 Apple 下载 BaseSystem.dmg / BaseSystem.chunklist"
    }
    Write-Line
    Write-Warn "将替换目标 U 盘里的 EFI\BOOT 和 EFI\OC"
    if (-not $WillFormat) {
        Write-Warn "旧 BOOT / OC 会自动备份"
    }
    Write-Warn "EFI\APPLE 和其他文件不会删除"
    if (-not $NoRecovery) {
        Write-Warn "缺少 macOS Recovery 时会写入 com.apple.recovery.boot"
    }
    Write-Line

    $answer = Read-Host "继续安装？[Y/n]"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        $answer = "Y"
    }

    if ($answer -notin @("y", "Y", "yes", "YES")) {
        Write-Line "已取消，没有修改 U 盘。"
        exit 0
    }
}

function Ensure-RecoveryBoot {
    param([object]$Drive)

    if ($NoRecovery) {
        Write-Warn "已指定 -NoRecovery，跳过 macOS Recovery 镜像。"
        return
    }

    $root = Get-DriveRoot $Drive
    $targetRecovery = Get-RecoveryBootPath $Drive
    $targetDmg = Join-Path $targetRecovery "BaseSystem.dmg"
    $targetChunklist = Join-Path $targetRecovery "BaseSystem.chunklist"

    Assert-UnderRoot -Path $targetRecovery -Root $root
    Assert-UnderRoot -Path $targetDmg -Root $root
    Assert-UnderRoot -Path $targetChunklist -Root $root

    if ((Test-RecoveryBootComplete $Drive) -and -not $ForceRecovery) {
        Write-Ok "macOS Recovery 已存在，保留：$targetRecovery"
        return
    }

    Write-Section "准备 macOS Recovery"
    if ($ForceRecovery -and (Test-Path -LiteralPath $targetRecovery)) {
        Write-Warn "将覆盖现有 com.apple.recovery.boot 中的 BaseSystem 文件。"
    }

    New-Item -ItemType Directory -Path $targetRecovery -Force | Out-Null

    $tempRecovery = Join-Path (New-WorkDir) "com.apple.recovery.boot"
    New-Item -ItemType Directory -Path $tempRecovery -Force | Out-Null
    $tempDmg = Join-Path $tempRecovery "BaseSystem.dmg"
    $tempChunklist = Join-Path $tempRecovery "BaseSystem.chunklist"

    try {
        $info = Get-AppleRecoveryInfo
        Write-Ok ("Apple Recovery 产品：{0}" -f $info.Product)

        Invoke-AppleAssetDownloadWithRetry -Url $info.ChunklistUrl -AssetToken $info.ChunklistToken -OutFile $tempChunklist -Label "Apple Recovery" -MaxAttempts 3
        $entries = @(Get-ChunklistEntries -Path $tempChunklist)
        Write-Ok ("BaseSystem.chunklist 解析通过：{0} 个 chunk" -f $entries.Count)
        $expectedDmgSize = Get-ChunklistTotalSize -Entries $entries

        Invoke-AppleAssetDownloadWithRetry -Url $info.DmgUrl -AssetToken $info.DmgToken -OutFile $tempDmg -Label "Apple Recovery" -ExpectedSize $expectedDmgSize -MaxAttempts 3
        Assert-RecoveryImageWithChunklist -DmgPath $tempDmg -ChunklistPath $tempChunklist

        Copy-Item -LiteralPath $tempChunklist -Destination $targetChunklist -Force
        Copy-Item -LiteralPath $tempDmg -Destination $targetDmg -Force
        Write-Ok "已写入 macOS Recovery：$targetRecovery"
    } catch {
        Remove-Item -LiteralPath $tempDmg -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tempChunklist -Force -ErrorAction SilentlyContinue
        Stop-WithError $_.Exception.Message
    }
}

function Warn-IfSmbiosPlaceholder {
    param([string]$SourcePath)

    $config = Join-Path $SourcePath "OC\config.plist"
    if (-not (Test-Path -LiteralPath $config -PathType Leaf)) {
        return
    }

    $text = Get-Content -LiteralPath $config -Raw
    if ($text -match "CHANGEME_|00000000-0000-0000-0000-000000000000|112233000000") {
        Write-Warn "来源 EFI 里检测到公开版 SMBIOS 占位值。"
        Write-Warn "测试启动可以继续；正式日用前建议填写自己的 SystemSerialNumber、MLB、SystemUUID、ROM。"
    }
}

function Install-EfiToUsb {
    param(
        [object]$Drive,
        [string]$SourcePath
    )

    $root = Get-DriveRoot $Drive
    $targetEfi = Join-Path $root "EFI"
    $targetBoot = Join-Path $targetEfi "BOOT"
    $targetOc = Join-Path $targetEfi "OC"
    $sourceBoot = Join-Path $SourcePath "BOOT"
    $sourceOc = Join-Path $SourcePath "OC"

    Assert-UnderRoot -Path $targetEfi -Root $root
    Assert-UnderRoot -Path $targetBoot -Root $root
    Assert-UnderRoot -Path $targetOc -Root $root

    $sourceFull = [System.IO.Path]::GetFullPath($SourcePath)
    $targetFull = [System.IO.Path]::GetFullPath($targetEfi)
    if ($sourceFull.StartsWith($targetFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Stop-WithError "来源 EFI 和目标 EFI 是同一个位置，已停止。"
    }

    New-Item -ItemType Directory -Path $targetEfi -Force | Out-Null

    if (-not $NoBackup -and ((Test-Path -LiteralPath $targetBoot) -or (Test-Path -LiteralPath $targetOc))) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupDir = Join-Path $targetEfi "backup-before-opencore-$stamp"
        Assert-UnderRoot -Path $backupDir -Root $root

        Write-Info "备份已有 BOOT / OC"
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

        if (Test-Path -LiteralPath $targetBoot) {
            Copy-Item -LiteralPath $targetBoot -Destination (Join-Path $backupDir "BOOT") -Recurse -Force
        }

        if (Test-Path -LiteralPath $targetOc) {
            Copy-Item -LiteralPath $targetOc -Destination (Join-Path $backupDir "OC") -Recurse -Force
        }

        Write-Ok "已备份到：$backupDir"
    }

    Write-Info "清理旧 BOOT / OC"
    if (Test-Path -LiteralPath $targetBoot) {
        Remove-Item -LiteralPath $targetBoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $targetOc) {
        Remove-Item -LiteralPath $targetOc -Recurse -Force
    }

    Write-Info "复制 BOOT 和 OC"
    Copy-Item -LiteralPath $sourceBoot -Destination $targetBoot -Recurse -Force
    Copy-Item -LiteralPath $sourceOc -Destination $targetOc -Recurse -Force

    if (-not (Test-Path -LiteralPath (Join-Path $targetOc "config.plist") -PathType Leaf)) {
        Stop-WithError "复制后没有找到目标 EFI\OC\config.plist。"
    }

    Write-Section "EFI 安装完成"
    Write-Ok "已复制 BOOT"
    Write-Ok "已复制 OC"
    Write-Ok "U 盘 EFI 安装完成"
}

function Show-FinalUsbSummary {
    param([object]$Drive)

    $root = Get-DriveRoot $Drive
    Write-Section "全部完成"
    Write-HostSafe "当前 U 盘根目录内容："
    Get-ChildItem -LiteralPath $root -Force | Sort-Object Name | ForEach-Object {
        Write-HostSafe ("  {0}" -f $_.Name)
    }
    Write-Line
    Write-HostSafe "完成。现在可以安全弹出 U 盘，然后用它启动 HP ProDesk 600 G4 DM。" "Green"
}

if ($Help) {
    Show-Usage
    exit 0
}

Start-FreshConsoleLine
Show-Banner

try {
    Write-Warn "默认不会格式化 U 盘；只有选择格式化或传入 -FormatUsb 才会清空目标盘。"
    Write-Warn "请确认目标是 U 盘，不是移动硬盘或内置硬盘。"

    $sourcePath = Select-EfiSource
    Warn-IfSmbiosPlaceholder $sourcePath

    $drive = Select-UsbDrive
    $willFormat = Select-FormatMode $drive
    if ($willFormat) {
        $drive = Format-UsbDrive $drive
    }
    Test-Fat32Target $drive

    Confirm-Install -Drive $drive -SourcePath $sourcePath -WillFormat $willFormat
    Install-EfiToUsb -Drive $drive -SourcePath $sourcePath
    Ensure-RecoveryBoot -Drive $drive
    Show-FinalUsbSummary -Drive $drive
} finally {
    Clear-WorkDirs
}
