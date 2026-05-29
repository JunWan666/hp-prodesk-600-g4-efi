# v13.7.8 - macOS Ventura 13.7.8

## 说明

这是 HP ProDesk 600 G4 DM 的 macOS Ventura 13.7.8 EFI 发布包，也是当前推荐版本。

这套 EFI 已经用于进入 macOS Ventura 13 系统，适合先完成安装和稳定启动。当前显卡部分保留安全显示模式，优先保证 DP 转 HDMI 环境能够亮屏。

## 主要内容

- macOS Ventura 13.7.8
- OpenCore 1.0.7
- SMBIOS: `Macmini8,1`
- 支持进入 macOS Ventura 13 系统
- 已加入 `USBPorts.kext`
- 临时开启 `XhciPortLimit`，提高安装器中 USB 鼠标键盘可用性
- 保留 `-igfxvesa`，优先保证 DP 转 HDMI 环境可亮屏
- 有线网卡使用 `IntelMausi.kext`
- 声卡参数使用 `alcid=23`

## 使用前必须处理

发布包中的 `config.plist` 已经脱敏，请先生成自己的 SMBIOS：

```text
SystemSerialNumber
MLB
SystemUUID
ROM
```

不要直接使用占位值。

## 安装方式

解压后把压缩包里的 `EFI` 文件夹复制到 U 盘或内置硬盘的 EFI 分区。

如果已经能从 U 盘进入 macOS，可以用仓库里的脚本把当前可用 EFI 复制到内置硬盘：

```bash
curl -fsSL https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install.sh | sh -s -- disk0s1 /Volumes/OPENCORE/EFI
```

执行前请先用 `diskutil list` 确认内置硬盘 EFI 分区是否真的是 `disk0s1`。

## 已知问题

- UHD 630 当前未开启完整硬件加速。
- DP 转 HDMI 的核显加速黑屏问题仍需后续 framebuffer 调整或更换主动式转接器验证。
- 声音、睡眠、Wi-Fi/蓝牙请按实际硬件继续测试。

## GitHub Release 填写建议

Tag:

```text
v13.7.8
```

Release title:

```text
HP ProDesk 600 G4 DM OpenCore EFI - Ventura 13.7.8
```

Release body 可以直接使用本文件内容。

## 上传资产

建议上传：

```text
dist/hp-prodesk-600-g4-dm-opencore-ventura-13.7.8.zip
dist/README-v13.7.8.md
```
