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

$Script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$Script:SelectedMode = ""

function Write-Line {
    param([string]$Text = "")
    Write-Host $Text
}

function Write-Info {
    param([string]$Text)
    Write-Host "==> " -NoNewline -ForegroundColor Blue
    Write-Host $Text
}

function Write-Ok {
    param([string]$Text)
    Write-Host "OK  " -NoNewline -ForegroundColor Green
    Write-Host $Text
}

function Write-Warn {
    param([string]$Text)
    Write-Host "!!  " -NoNewline -ForegroundColor Yellow
    Write-Host $Text
}

function Stop-WithError {
    param([string]$Text)
    Write-Host "错误：" -NoNewline -ForegroundColor Red
    Write-Host $Text
    exit 1
}

function Write-Rule {
    Write-Host "──────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
}

function Write-Section {
    param([string]$Title)
    Write-Line
    Write-Rule
    Write-Host "  $Title" -ForegroundColor White
    Write-Rule
}

function Show-Banner {
    Write-Host "╭────────────────────────────────────────────────────────────╮" -ForegroundColor Cyan
    Write-Host "│  HP ProDesk 600 G4 DM                                      │" -ForegroundColor Cyan
    Write-Host "│  OpenCore EFI USB Installer                                │" -ForegroundColor Cyan
    Write-Host "│  Windows · Ventura 13.7.8 · safe / igpu · DW1820A Ready    │" -ForegroundColor Cyan
    Write-Host "╰────────────────────────────────────────────────────────────╯" -ForegroundColor Cyan
    Write-Line
}

function Show-Usage {
    $usage = @"
用法：
  powershell -ExecutionPolicy Bypass -File .\script\install-efi-to-usb.ps1
  powershell -ExecutionPolicy Bypass -File .\script\install-efi-to-usb.ps1 -DriveLetter E
  powershell -ExecutionPolicy Bypass -File .\script\install-efi-to-usb.ps1 -DriveLetter E -Source .\all_efi\igpu\13.7.8\EFI -Yes

说明：
  - 这个脚本用于在 Windows 上把本仓库 EFI 安装到 U 盘。
  - 脚本不会格式化 U 盘，只会更新 U 盘里的 EFI\BOOT 和 EFI\OC。
  - 已有 EFI\BOOT / EFI\OC 会先备份到 EFI\backup-before-opencore-时间。
  - EFI\APPLE 会保留。
  - 默认来源是 Ventura 13.7.8 igpu 核显加速版。
  - 目标 U 盘建议使用 FAT32；非 FAT32 默认会停止。
"@
    Write-Host $usage
}

function Get-SourceOptions {
    @(
        [pscustomobject]@{
            Index = 1
            Name = "Ventura 13.7.8 - igpu 核显加速版"
            Path = Join-Path $Script:RepoRoot "all_efi\igpu\13.7.8\EFI"
            Desc = "推荐日用；需要 DP 直连或主动式 DP 转 HDMI；包含 DW1820A"
        },
        [pscustomobject]@{
            Index = 2
            Name = "Ventura 13.7.8 - safe 安全亮屏版"
            Path = Join-Path $Script:RepoRoot "all_efi\safe\13.7.8\EFI"
            Desc = "首次安装、黑屏救援、线材不确定时使用；包含 DW1820A"
        },
        [pscustomobject]@{
            Index = 3
            Name = "Monterey 12.7.6 - igpu 核显加速版"
            Path = Join-Path $Script:RepoRoot "all_efi\igpu\12.7.6\EFI"
            Desc = "历史备用版本"
        },
        [pscustomobject]@{
            Index = 4
            Name = "Monterey 12.7.6 - safe 安全亮屏版"
            Path = Join-Path $Script:RepoRoot "all_efi\safe\12.7.6\EFI"
            Desc = "历史备用 / 救援版本"
        }
    )
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
        foreach ($option in Get-SourceOptions) {
            $prefix = if ($option.Index -eq 1) { "[默认]" } else { "      " }
            Write-Host ("  {0} {1}) {2}" -f $prefix, $option.Index, $option.Name) -ForegroundColor Green
            Write-Host ("          {0}" -f $option.Desc)
            Write-Host ("          {0}" -f $option.Path) -ForegroundColor DarkGray
            Write-Line
        }
        Write-Host "        5) 手动输入 EFI 路径"
        Write-Host "        0) 退出"
        Write-Line

        $choice = Read-Host "请选择 EFI 来源 [1]"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = "1"
        }

        if ($choice -eq "0") {
            Write-Line "已退出，没有修改 U 盘。"
            exit 0
        }

        if ($choice -eq "5") {
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

        $selected = Get-SourceOptions | Where-Object { $_.Index -eq [int]$choice } | Select-Object -First 1
        if (-not $selected) {
            Write-Warn "无效选择：$choice"
            continue
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
            $prefix = if ($index -eq 1) { "[默认]" } else { "      " }
            Write-Host ("  {0} {1}) {2}\  {3}  {4}  总计 {5}  可用 {6}" -f $prefix, $index, $drive.DeviceID, $label, $fs, $size, $free)
        }
        Write-Host "        0) 退出"
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
        [string]$SourcePath
    )

    if ($Yes) {
        return
    }

    Write-Section "安装确认"
    Write-Host ("  目标 U 盘：{0}\  {1}  {2}" -f $Drive.DeviceID, $Drive.VolumeName, $Drive.FileSystem)
    Write-Host ("  来源 EFI ：{0}" -f $SourcePath)
    Write-Host ("  模式     ：{0}" -f $Script:SelectedMode)
    Write-Line
    Write-Warn "将替换目标 U 盘里的 EFI\BOOT 和 EFI\OC"
    Write-Warn "旧 BOOT / OC 会自动备份"
    Write-Warn "EFI\APPLE 和其他文件不会删除"
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

    $root = $Drive.DeviceID + "\"
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

    Write-Section "安装完成"
    Write-Ok "已复制 BOOT"
    Write-Ok "已复制 OC"
    Write-Ok "U 盘 EFI 安装完成"
    Write-Line
    Write-Host "当前 U 盘 EFI 内容："
    Get-ChildItem -LiteralPath $targetEfi -Force | Sort-Object Name | ForEach-Object {
        Write-Host ("  {0}" -f $_.Name)
    }
    Write-Line
    Write-Host "完成。现在可以安全弹出 U 盘，然后用它启动 HP ProDesk 600 G4 DM。" -ForegroundColor Green
}

if ($Help) {
    Show-Usage
    exit 0
}

Show-Banner

Write-Warn "此脚本不会格式化 U 盘，只会更新 EFI\BOOT 和 EFI\OC。"
Write-Warn "请确认目标是 U 盘，不是移动硬盘或内置硬盘。"

$sourcePath = Select-EfiSource
Warn-IfSmbiosPlaceholder $sourcePath

$drive = Select-UsbDrive
Test-Fat32Target $drive

Confirm-Install -Drive $drive -SourcePath $sourcePath
Install-EfiToUsb -Drive $drive -SourcePath $sourcePath
