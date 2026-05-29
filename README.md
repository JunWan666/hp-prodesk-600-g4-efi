<div align="center">

# HP ProDesk 600 G4 DM OpenCore EFI

适用于 HP ProDesk 600 G4 Desktop Mini 的 OpenCore 引导配置，已用于安装并进入 macOS Ventura 13。

![OpenCore](https://img.shields.io/badge/OpenCore-1.0.7-0f172a?style=for-the-badge&logo=apple&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-Ventura%2013.7.8-2563eb?style=for-the-badge&logo=macos&logoColor=white)
![Model](https://img.shields.io/badge/HP-ProDesk%20600%20G4%20DM-0096d6?style=for-the-badge&logo=hp&logoColor=white)
![CPU](https://img.shields.io/badge/Intel-i3--9100T-0071c5?style=for-the-badge&logo=intel&logoColor=white)
![iGPU](https://img.shields.io/badge/UHD%20630-Safe%20VESA-f97316?style=for-the-badge)

</div>

## 说明

这是给 HP ProDesk 600 G4 DM 小主机整理的 OpenCore EFI。当前重点是稳定引导和安装 macOS Ventura 13，仓库内同时保留了一份 Monterey 12.7.6 的历史可用配置。

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
| `all_efi/13.7.8/EFI` | 推荐 | OpenCore 1.0.7，已用于进入 macOS Ventura 13 系统 |
| `all_efi/12.7.6/EFI` | 备用 | 旧版 OpenCore，曾用于安装 macOS Monterey 12.7.6 |

## 当前可用情况

| 功能 | 状态 | 备注 |
| --- | --- | --- |
| Ventura 13 引导 | 可用 | 已进入系统 |
| Monterey 12 引导 | 可用 | 历史成功配置 |
| 有线网卡 | 可用 | `IntelMausi.kext` |
| USB 鼠标键盘 | 可用 | `USBPorts.kext`，Ventura EFI 临时开启 `XhciPortLimit` |
| 声音 | 待复测 | 使用 `alcid=23` |
| UHD 630 核显加速 | 未完成 | 当前保留 `-igfxvesa`，能亮屏但无硬件加速 |
| DP 转 HDMI | 待优化 | 当前以亮屏和安装为优先 |

## 目录结构

```text
.
├── all_efi
│   ├── 12.7.6
│   │   └── EFI
│   ├── 13.7.8
│   │   └── EFI
│   └── README.md
├── dist
│   ├── hp-prodesk-600-g4-dm-opencore-monterey-12.7.6.zip
│   ├── hp-prodesk-600-g4-dm-opencore-ventura-13.7.8.zip
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

## Release 文件

`dist` 目录里已经整理好 GitHub Release 可上传文件：

| Release | 压缩包 | 说明 |
| --- | --- | --- |
| `v13.7.8` | `dist/hp-prodesk-600-g4-dm-opencore-ventura-13.7.8.zip` | 当前推荐，Ventura 13.7.8 |
| `v12.7.6` | `dist/hp-prodesk-600-g4-dm-opencore-monterey-12.7.6.zip` | 历史备用，Monterey 12.7.6 |

GitHub Release 的正文可以直接复制 `release_md` 目录里对应版本的 Markdown。

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
curl -fsSL https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install.sh | sh -s -- disk0s1 /Volumes/OPENCORE/EFI
```

上面命令的含义：

- `disk0s1` 是内置硬盘 EFI 分区，请按 `diskutil list` 的结果确认。
- `/Volumes/OPENCORE/EFI` 是 U 盘里当前可用的 EFI 路径。如果你的 U 盘卷标不是 `OPENCORE`，请改成实际路径。

脚本会自动：

- 挂载内置硬盘 EFI 分区
- 备份已有的 `EFI/BOOT` 和 `EFI/OC`
- 复制本仓库的 `BOOT` 和 `OC`
- 保留苹果安装器可能创建的 `EFI/APPLE`

完成后关机，拔掉 U 盘，再从内置硬盘启动测试。

如果已经把本仓库 clone 到 macOS，也可以本地执行：

```bash
sh ./script/install.sh disk0s1 ./all_efi/13.7.8/EFI
```

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

## 已知问题

### UHD 630 目前是安全显示模式

Ventura EFI 当前保留：

```text
-igfxvesa
```

这可以保证 DP 转 HDMI 环境下更容易亮屏进入安装器和系统，但会导致显存显示很小、动画卡顿、没有完整 QE/CI 硬件加速。

后续优化方向：

- 使用原生 DP 显示器测试核显加速
- 使用明确标注 Active / 主动式 / DP 1.2 to HDMI 2.0 / 4K60 的转接器
- 调整 UHD 630 framebuffer connector patch
- 考虑 HP 原厂 Flex IO HDMI 模块

### 不建议直接照搬到不同硬件

同为 HP 600 G4 DM 也可能存在 CPU、网卡、Wi-Fi、显示输出模块不同的情况。使用前请先确认硬件。

## 免责声明

本仓库只提供 OpenCore 配置学习与备份。macOS 版权归 Apple 所有，请自行遵守所在地区法律法规和 Apple 软件许可协议。
