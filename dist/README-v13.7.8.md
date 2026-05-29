# v13.7.8 - macOS Ventura 13.7.8

## 说明

这是 HP ProDesk 600 G4 DM 的 macOS Ventura 13.7.8 EFI 发布包，也是当前推荐版本。

这套 EFI 已经用于进入 macOS Ventura 13 系统，适合先完成安装和稳定启动。默认保留安全显示参数，确认使用 DP 直连显示器或主动式 DP 转 HDMI 后，可以按 README 删除 `-igfxvesa` 开启 UHD 630 核显加速。

## 主要内容

- macOS Ventura 13.7.8
- OpenCore 1.0.7
- SMBIOS: `Macmini8,1`
- 支持进入 macOS Ventura 13 系统
- 已加入 `USBPorts.kext`
- 临时开启 `XhciPortLimit`，提高安装器中 USB 鼠标键盘可用性
- 默认保留 `-igfxvesa`，优先保证安装阶段可亮屏
- DP 直连显示器已验证可开启 UHD 630 核显加速
- 主动式 DP 转 HDMI 已验证可开启 UHD 630 核显加速
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
curl -fsSL https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install.sh | sh -s -- disk0s1
```

执行前请先用 `diskutil list` 确认内置硬盘 EFI 分区是否真的是 `disk0s1`。来源 EFI 可以省略，脚本会自动查找包含 `BOOT` 和 `OC` 的 EFI 目录。

## 核显加速

默认配置保留 `-igfxvesa`，用于提高安装和首次亮屏成功率。开启核显加速时，请先确认显示连接方式：

- 推荐 DP 直连 DP 显示器。
- DP 转 HDMI 需要主动式转接器或转接线，建议选择标注 Active / 主动式 / DP 1.2 to HDMI 2.0 / 4K60 的型号。
- 普通被动式 DP 转 HDMI 不保证可用。

开启方式：删除 `EFI/OC/config.plist` 里 `boot-args` 中的 `-igfxvesa`，保留：

```text
keepsyms=1 darkwake=2 -v debug=0x100 igfxonln=1 igfxagdc=0 alcid=23
```

如果黑屏或无信号，把 `-igfxvesa` 加回去即可恢复安全亮屏模式。

## 已知问题

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
