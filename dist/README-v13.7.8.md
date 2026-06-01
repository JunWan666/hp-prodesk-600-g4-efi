# HP ProDesk 600 G4 DM OpenCore EFI - Ventura 13.7.8

这是 HP ProDesk 600 G4 Desktop Mini 的 macOS Ventura 13.7.8 OpenCore EFI Release。当前版本已验证可以进入 macOS Ventura 13.7.8，支持 UHD 630 核显加速，并已加入 Dell DW1820A / Broadcom BCM94350ZAE 无线网卡和蓝牙驱动。

> 本次重新打包修复了旧 ZIP 在 macOS 自带 `unzip` 下可能因为 Windows 反斜杠路径导致解压失败的问题。新版 ZIP 内部路径已经改为 `EFI/OC/...`，可直接在 macOS 解压使用。

## 本次上传文件

请在 GitHub Release `v13.7.8` 里上传下面两个 ZIP：

| 文件 | 模式 | 适合场景 | SHA256 |
| --- | --- | --- | --- |
| `hp-prodesk-600-g4-dm-ventura-13.7.8-igpu.zip` | 核显加速版 | 推荐日用；需要 DP 直连显示器，或主动式 DP 转 HDMI | `10b10e6c30f986c16f1e4cbbfef35cfe80cd2791d33d5881f4731a81cfa03f97` |
| `hp-prodesk-600-g4-dm-ventura-13.7.8-safe.zip` | 安全亮屏版 | 首次安装、黑屏救援、显示器线材不确定 | `0232d1dba1a4b754cb3b8777ffb2c4ad4c5b7da8d51631c53fd6d4e8c9ba0fa4` |

对应本地文件位置：

```text
dist/hp-prodesk-600-g4-dm-ventura-13.7.8-igpu.zip
dist/hp-prodesk-600-g4-dm-ventura-13.7.8-safe.zip
```

## 适用硬件

| 项目 | 配置 |
| --- | --- |
| 机型 | HP ProDesk 600 G4 Desktop Mini |
| CPU | Intel Core i3-9100T |
| 核显 | Intel UHD Graphics 630 |
| 有线网卡 | Intel I219-LM |
| 无线网卡 | Dell DW1820A / Broadcom BCM94350ZAE，已验证 |
| 声卡 | Conexant，当前使用 `alcid=23` |
| SMBIOS | `Macmini8,1` |
| OpenCore | 1.0.7 |

同为 HP ProDesk 600 G4 DM，也可能因为 CPU、网卡、无线网卡、显示输出模块不同而需要调整。不同硬件请先备份原 EFI 再测试。

## 怎么选择

优先建议：

- 已经有 DP 显示器，或者确认使用的是主动式 DP 转 HDMI：下载 `igpu`。
- 首次安装、不确定线材、启动后黑屏、需要救援：下载 `safe`。
- 普通被动式 DP 转 HDMI 线不保证可用。表现可能是跑码后无信号，或者进入系统黑屏。

两个包的核心区别：

- `safe` 保留 `-igfxvesa`，更容易亮屏，但没有完整 UHD 630 核显加速，系统可能显示几 MB 显存，动画会卡顿。
- `igpu` 删除 `-igfxvesa`，用于开启 UHD 630 核显加速，适合日常使用。

## 使用前必须修改 SMBIOS

公开版已经清理个人 SMBIOS 信息。使用前必须重新生成并填写自己的：

- `SystemSerialNumber`
- `MLB`
- `SystemUUID`
- `ROM`

建议使用 GenSMBIOS 生成 `Macmini8,1` 的一套新序列号。不要直接使用仓库里的占位值。

## 使用方式

1. 下载适合自己的 ZIP。
2. 解压后会得到 `EFI` 目录。
3. 把 `EFI` 放到 U 盘 EFI 分区，或已经安装完成后的内置硬盘 EFI 分区。
4. 第一次替换 EFI 后，建议在 OpenCore 界面执行一次 `Reset NVRAM`。
5. 进入系统后确认显卡、网卡、USB、声音等功能。

如果已经能通过 U 盘进入 macOS，可以用仓库脚本把当前 U 盘 EFI 复制到内置硬盘 EFI 分区：

```bash
curl -fsSL https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install.sh | sh
```

脚本会自动识别唯一的内置硬盘 EFI 分区。选择来源时：

- 直接回车：使用当前 U 盘 EFI。
- 输入 `2`：从 GitHub 下载 `igpu` 核显加速版。
- 输入 `3`：从 GitHub 下载 `safe` 安全亮屏版。
- 输入 `4`：手动输入 EFI 路径。

安装确认页直接回车等同于 `Y`，输入 `n` 才取消。

如果自动识别失败，先在 macOS 里确认磁盘：

```bash
diskutil list
```

通常内置硬盘 EFI 是 `disk0s1`，可以手动指定：

```bash
curl -fsSL https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install.sh | sh -s -- disk0s1
```

脚本会备份内置硬盘已有的 `EFI/BOOT` 和 `EFI/OC`，清理旧目录后再复制当前可用的 EFI，并保留 `EFI/APPLE`。

## 核显加速和显示线材

`igpu` 版本用于开启 UHD 630 核显加速。已验证：

- DP 直连 DP 显示器可用。
- 主动式 DP 转 HDMI 可用。

不建议使用普通被动式 DP 转 HDMI 线。选购转接器时优先看是否标注 `Active`、`主动式`、`DP 1.2 to HDMI 2.0`、`4K60`。

## DW1820A 无线和蓝牙

本 Release 的 `igpu` 和 `safe` 两个 ZIP 都已加入 Dell DW1820A / Broadcom BCM94350ZAE 支持。已包含这些 kext：

```text
AirportBrcmFixup.kext
BlueToolFixup.kext
BrcmFirmwareData.kext
BrcmPatchRAM3.kext
```

对应启动参数已写入：

```text
brcmfx-country=#a brcmfx-aspm=0 brcmfx-driver=2
```

使用注意：

- 网卡需要接好 MAIN / AUX 天线。
- 不要把自己网卡的 MAC 地址写进公开仓库或截图里。
- 如果 Wi-Fi 可用但蓝牙不可用，优先检查网卡蓝牙对应的 USB 端口映射。
- 这个无线方案是在 Ventura 13.7.8 上验证通过的；Monterey 12.7.6 历史包未在本次更新中重新测试。

## 黑屏恢复

如果使用 `igpu` 后黑屏：

1. 先换回 `safe` 版本启动。
2. 或者把 `EFI/OC/config.plist` 里的 `boot-args` 加回 `-igfxvesa`。
3. 进入 OpenCore 后执行一次 `Reset NVRAM`。
4. 确认线材是 DP 直连或主动式 DP 转 HDMI。

## 已知情况

- Ventura 13.7.8 可进入系统。
- 有线网卡可用。
- Dell DW1820A Wi-Fi / 蓝牙可用。
- USB 鼠标键盘可用。
- UHD 630 核显加速在 DP 直连和主动式 DP 转 HDMI 下可用。
- 声音使用 `alcid=23`，不同机器可能需要自行复测。

## SHA256

```text
10b10e6c30f986c16f1e4cbbfef35cfe80cd2791d33d5881f4731a81cfa03f97  hp-prodesk-600-g4-dm-ventura-13.7.8-igpu.zip
0232d1dba1a4b754cb3b8777ffb2c4ad4c5b7da8d51631c53fd6d4e8c9ba0fa4  hp-prodesk-600-g4-dm-ventura-13.7.8-safe.zip
```

## 免责声明

本 Release 仅提供 OpenCore 配置学习与备份。macOS 版权归 Apple 所有，请自行遵守所在地区法律法规和 Apple 软件许可协议。
