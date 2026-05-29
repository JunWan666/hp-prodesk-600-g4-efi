# v12.7.6 - macOS Monterey 12.7.6

## 说明

这是 HP ProDesk 600 G4 DM 的 macOS Monterey 12.7.6 EFI 发布包。

这套 EFI 是历史可用备份，适合作为 Monterey 12 的备用方案。当前主推版本仍然是 Ventura 13.7.8。

## 主要内容

- macOS Monterey 12.7.6
- SMBIOS: `Macmini8,1`
- 默认保留 `-igfxvesa`，优先保证安装阶段可亮屏
- 有线网卡使用 `IntelMausi.kext`
- 声卡参数使用 `alcid=23`
- `XhciPortLimit` 当前为关闭状态
- 包含 OpenCore 图形界面资源和历史测试用 Kext

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

## 已知问题

- 这是 Monterey 12 的历史可用配置，不是当前主推版本。
- UHD 630 可参考主 README 删除 `-igfxvesa` 开启核显加速；建议使用 DP 直连显示器或主动式 DP 转 HDMI。
- 声音、睡眠、Wi-Fi/蓝牙请按实际硬件继续测试。

## GitHub Release 填写建议

Tag:

```text
v12.7.6
```

Release title:

```text
HP ProDesk 600 G4 DM OpenCore EFI - Monterey 12.7.6
```

Release body 可以直接使用本文件内容。

## 上传资产

建议上传：

```text
dist/hp-prodesk-600-g4-dm-opencore-monterey-12.7.6.zip
dist/README-v12.7.6.md
```
