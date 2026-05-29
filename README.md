<div align="center">

# HP ProDesk 600 G4 DM OpenCore EFI

适用于 HP ProDesk 600 G4 Desktop Mini 的 OpenCore 引导配置，已用于安装并进入 macOS Ventura 13。

![OpenCore](https://img.shields.io/badge/OpenCore-1.0.7-0f172a?style=for-the-badge&logo=apple&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-Ventura%2013.7.8-2563eb?style=for-the-badge&logo=macos&logoColor=white)
![Model](https://img.shields.io/badge/HP-ProDesk%20600%20G4%20DM-0096d6?style=for-the-badge&logo=hp&logoColor=white)
![CPU](https://img.shields.io/badge/Intel-i3--9100T-0071c5?style=for-the-badge&logo=intel&logoColor=white)
![iGPU](https://img.shields.io/badge/UHD%20630-DP%20Accel%20Ready-16a34a?style=for-the-badge)

</div>

## 说明

这是给 HP ProDesk 600 G4 DM 小主机整理的 OpenCore EFI。当前重点是稳定引导和安装 macOS Ventura 13，仓库内同时保留了一份 Monterey 12.7.6 的历史可用配置。UHD 630 核显加速已通过 DP 直连显示器验证，主动式 DP 转 HDMI 也已验证可用。

公开版已经移除个人 SMBIOS 信息。使用前必须重新生成自己的 `SystemSerialNumber`、`MLB`、`SystemUUID` 和 `ROM`。

## 硬件配置

| 项目 | 配置 |
| --- | --- |
| 机型 | HP ProDesk 600 G4 Desktop Mini |
| CPU | Intel Core i3-9100T |
| 核显 | Intel UHD Graphics 630 |
| 有线网卡 | Intel I219-LM |
| 声卡 | Conexant，当前使用 `alcid=23` |
| 硬盘 | Samsung NVMe 256GB |
| SMBIOS | `Macmini8,1` |

## EFI 状态

| 版本目录 | 状态 | 说明 |
| --- | --- | --- |
| `all_efi/igpu/13.7.8/EFI` | 推荐日用 | Ventura 13.7.8，UHD 630 核显加速版 |
| `all_efi/safe/13.7.8/EFI` | 推荐安装/救援 | Ventura 13.7.8，安全亮屏版 |
| `all_efi/igpu/12.7.6/EFI` | 备用 | Monterey 12.7.6，核显加速版 |
| `all_efi/safe/12.7.6/EFI` | 备用/救援 | Monterey 12.7.6，安全亮屏版 |

## 当前可用情况

| 功能 | 状态 | 备注 |
| --- | --- | --- |
| Ventura 13 引导 | 可用 | 已进入系统 |
| Monterey 12 引导 | 可用 | 历史成功配置 |
| 有线网卡 | 可用 | `IntelMausi.kext` |
| USB 鼠标键盘 | 可用 | `USBPorts.kext`，Ventura EFI 临时开启 `XhciPortLimit` |
| 声音 | 待复测 | 使用 `alcid=23` |
| UHD 630 核显加速 | 可开启 | 使用 `igpu` 目录；`safe` 目录保留 `-igfxvesa` 用于亮屏救援 |
| DP 输出 | 可用 | DP 直连显示器已验证可开核显加速 |
| DP 转 HDMI | 可用 | 需主动式 DP 转 HDMI；普通被动线不保证 |

## 目录结构

```text
.
├── all_efi
│   ├── safe
│   │   ├── 12.7.6
│   │   │   └── EFI
│   │   └── 13.7.8
│   │       └── EFI
│   ├── igpu
│   │   ├── 12.7.6
│   │   │   └── EFI
│   │   └── 13.7.8
│   │       └── EFI
│   └── README.md
├── dist
│   ├── hp-prodesk-600-g4-dm-monterey-12.7.6-igpu.zip
│   ├── hp-prodesk-600-g4-dm-monterey-12.7.6-safe.zip
│   ├── hp-prodesk-600-g4-dm-ventura-13.7.8-igpu.zip
│   ├── hp-prodesk-600-g4-dm-ventura-13.7.8-safe.zip
│   ├── README-v12.7.6.md
│   ├── README-v13.7.8.md
│   └── README.md
├── release_md
│   ├── v12.7.6.md
│   └── v13.7.8.md
├── script
│   └── install.sh
└── README.md
```

## 下载

可以按系统版本选择 Release。每个 Release 里同时提供 `igpu` 核显加速版和 `safe` 安全亮屏版两个 ZIP。

| Release | macOS | 推荐文件 | 安全/救援文件 | 说明 |
| --- | --- | --- | --- | --- |
| [`v13.7.8`](https://github.com/JunWan666/hp-prodesk-600-g4-efi/releases/tag/v13.7.8) | Ventura 13.7.8 | [`hp-prodesk-600-g4-dm-ventura-13.7.8-igpu.zip`](https://github.com/JunWan666/hp-prodesk-600-g4-efi/releases/download/v13.7.8/hp-prodesk-600-g4-dm-ventura-13.7.8-igpu.zip) | [`hp-prodesk-600-g4-dm-ventura-13.7.8-safe.zip`](https://github.com/JunWan666/hp-prodesk-600-g4-efi/releases/download/v13.7.8/hp-prodesk-600-g4-dm-ventura-13.7.8-safe.zip) | 推荐日用版本 |
| [`v12.7.6`](https://github.com/JunWan666/hp-prodesk-600-g4-efi/releases/tag/v12.7.6) | Monterey 12.7.6 | [`hp-prodesk-600-g4-dm-monterey-12.7.6-igpu.zip`](https://github.com/JunWan666/hp-prodesk-600-g4-efi/releases/download/v12.7.6/hp-prodesk-600-g4-dm-monterey-12.7.6-igpu.zip) | [`hp-prodesk-600-g4-dm-monterey-12.7.6-safe.zip`](https://github.com/JunWan666/hp-prodesk-600-g4-efi/releases/download/v12.7.6/hp-prodesk-600-g4-dm-monterey-12.7.6-safe.zip) | 历史备用版本 |

GitHub Release 的正文可以直接复制 `release_md` 目录里对应版本的 Markdown。`igpu` 需要 DP 直连显示器，或主动式 DP 转 HDMI；黑屏、安装、救援优先用 `safe`。

## 使用前必须修改

打开对应版本的：

```text
EFI/OC/config.plist
```

修改 `PlatformInfo -> Generic` 里的这些值：

```text
SystemSerialNumber = CHANGEME_SERIAL
MLB                = CHANGEME_MLB
SystemUUID         = 00000000-0000-0000-0000-000000000000
ROM                = 112233000000
```

建议使用 GenSMBIOS 生成 `Macmini8,1` 的一套新序列号。不要直接使用仓库里的占位值。

## 一键安装到内置硬盘 EFI

已经能从 U 盘启动进 macOS 后，可以把 EFI 复制到内置硬盘 EFI 分区。

先在 macOS 里查看磁盘：

```bash
diskutil list
```

通常内置硬盘 EFI 是 `disk0s1`。确认后可以在线执行：

```bash
curl -fsSL https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install.sh | sh -s -- disk0s1
```

上面命令的含义：

- `disk0s1` 是内置硬盘 EFI 分区，请按 `diskutil list` 的结果确认。
- 来源 EFI 目录可以省略，脚本会自动查找 U 盘或本地仓库里包含 `BOOT` 和 `OC` 的 EFI。
- 如果找到多个候选 EFI，脚本会列出路径并停止，这时把正确路径作为第二个参数重新执行即可。

例如手动指定来源 EFI：

```bash
curl -fsSL https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install.sh | sh -s -- disk0s1 /Volumes/EFI/EFI
```

如果确认无误，也可以加 `--yes` 跳过安装前确认：

```bash
curl -fsSL https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install.sh | sh -s -- disk0s1 --yes
```

脚本会自动：

- 挂载内置硬盘 EFI 分区
- 尝试挂载外置 U 盘的 EFI 分区
- 自动识别来源 EFI 目录
- 备份已有的 `EFI/BOOT` 和 `EFI/OC`
- 复制本仓库的 `BOOT` 和 `OC`
- 保留苹果安装器可能创建的 `EFI/APPLE`

完成后关机，拔掉 U 盘，再从内置硬盘启动测试。

如果已经把本仓库 clone 到 macOS，也可以本地执行：

```bash
sh ./script/install.sh disk0s1 ./all_efi/igpu/13.7.8/EFI
```

如果需要安全亮屏版，把路径改成 `./all_efi/safe/13.7.8/EFI`。

注意：在线执行脚本前建议先打开脚本链接看一眼内容。不要在没有确认目标 EFI 分区的情况下直接执行。

## Ventura 13 安装提示

建议 BIOS 设置：

- 关闭 Secure Boot
- 关闭 Fast Boot
- 关闭 CSM / Legacy Boot
- SATA Mode 设为 AHCI
- DVMT Pre-Allocated 设置为 64MB 或更高

安装流程：

1. 用 U 盘启动 OpenCore。
2. 选择 `macOS Recovery` 或安装器条目。
3. 进入磁盘工具，抹掉目标盘为 APFS / GUID。
4. 安装 macOS Ventura。
5. 中途重启时继续从 OpenCore 选择 `macOS Installer` 或内置系统盘。
6. 系统安装完成后，再把 EFI 安装到内置硬盘 EFI 分区。

## 核显加速

### 显示线材要求

UHD 630 开启硬件加速后，对显示输出更挑剔。已验证可用的连接方式：

- DP 直连 DP 显示器，推荐。
- 主动式 DP 转 HDMI 转接器或转接线，推荐选择标注 Active / 主动式 / DP 1.2 to HDMI 2.0 / 4K60 的型号。

不建议使用普通被动式 DP 转 HDMI 线。被动线可能在跑码后无信号，或者进系统黑屏。

### 开启方式

`safe` 目录里的 EFI 保留：

```text
-igfxvesa
```

这个参数用于安全亮屏，但会禁用完整核显加速，表现通常是显存只有几 MB、动画卡顿、没有 Metal/QE/CI。`igpu` 目录里的 EFI 已经删除该参数，用于开启 UHD 630 核显加速。

确认你使用 DP 直连显示器，或主动式 DP 转 HDMI 后，把 `EFI/OC/config.plist` 里 `boot-args` 的 `-igfxvesa` 删除即可。删除后建议保留这些参数：

```text
keepsyms=1 darkwake=2 -v debug=0x100 igfxonln=1 igfxagdc=0 alcid=23
```

当前 EFI 已经包含 UHD 630 所需的主要属性：

```text
AAPL,ig-platform-id = 07009B3E
device-id           = 9B3E0000
```

### macOS 下修改示例

先挂载要修改的 EFI 分区，并确认路径里存在 `EFI/OC/config.plist`。下面以 `/Volumes/EFI/EFI/OC/config.plist` 为例：

```bash
sudo cp /Volumes/EFI/EFI/OC/config.plist /Volumes/EFI/EFI/OC/config.before-igpu-accel.plist
sudo /usr/libexec/PlistBuddy -c "Set :NVRAM:Add:7C436110-AB2A-4BBB-A880-FE41995C9F82:boot-args keepsyms=1 darkwake=2 -v debug=0x100 igfxonln=1 igfxagdc=0 alcid=23" /Volumes/EFI/EFI/OC/config.plist
sync
```

如果启动后仍然显示 3MB 显存，可以在 OpenCore 界面按空格，执行一次 `Reset NVRAM`，再重新启动。

### 黑屏恢复

如果开启加速后无信号，把 `-igfxvesa` 加回 `boot-args`，或恢复开启前备份的 `config.before-igpu-accel.plist`。

恢复为安全亮屏参数示例：

```bash
sudo /usr/libexec/PlistBuddy -c "Set :NVRAM:Add:7C436110-AB2A-4BBB-A880-FE41995C9F82:boot-args keepsyms=1 darkwake=2 -v debug=0x100 igfxonln=1 igfxagdc=0 alcid=23 -igfxvesa" /Volumes/EFI/EFI/OC/config.plist
sync
```

## 已知问题

### 不建议直接照搬到不同硬件

同为 HP 600 G4 DM 也可能存在 CPU、网卡、Wi-Fi、显示输出模块不同的情况。使用前请先确认硬件。

## 免责声明

本仓库只提供 OpenCore 配置学习与备份。macOS 版权归 Apple 所有，请自行遵守所在地区法律法规和 Apple 软件许可协议。
