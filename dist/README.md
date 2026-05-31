# GitHub Release 上传说明

这个目录放 GitHub Release 需要上传的压缩包和正文说明。现在按 2 个 Release 发布，每个 Release 里上传 `igpu` 和 `safe` 两个 ZIP。

| Release | 上传压缩包 | Release 正文 |
| --- | --- | --- |
| `v13.7.8` | `hp-prodesk-600-g4-dm-ventura-13.7.8-igpu.zip`、`hp-prodesk-600-g4-dm-ventura-13.7.8-safe.zip` | `README-v13.7.8.md` |
| `v12.7.6` | `hp-prodesk-600-g4-dm-monterey-12.7.6-igpu.zip`、`hp-prodesk-600-g4-dm-monterey-12.7.6-safe.zip` | `README-v12.7.6.md` |

## 选择建议

- `igpu`：核显加速版，推荐日用；需要 DP 直连显示器，或主动式 DP 转 HDMI。
- `safe`：安全亮屏版，适合安装、黑屏救援、排查显示输出问题。
- 日常优先建议使用 `v13.7.8`，该版本已加入并验证 Dell DW1820A / Broadcom BCM94350ZAE 无线和蓝牙支持。

## 注意

所有 EFI 的 `config.plist` 都已经脱敏，使用前必须重新生成自己的 SMBIOS 信息。

校验值见 `SHA256SUMS.txt`。
