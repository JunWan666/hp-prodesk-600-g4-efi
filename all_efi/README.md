# EFI 版本说明

这里保存不同 macOS 版本测试过的 EFI。

| 目录 | OpenCore | macOS | 状态 |
| --- | --- | --- | --- |
| `13.7.8/EFI` | 1.0.7 | Ventura 13 | 推荐，已进入系统 |
| `12.7.6/EFI` | 旧版 | Monterey 12 | 历史可用备份 |

公开版已清理个人 SMBIOS 信息。使用前请重新生成并填写：

- `SystemSerialNumber`
- `MLB`
- `SystemUUID`
- `ROM`

当前 `13.7.8` EFI 以稳定亮屏和安装为优先，默认保留 `-igfxvesa`。如果使用 DP 直连显示器，或主动式 DP 转 HDMI，可以按主 README 的说明删除 `-igfxvesa` 开启 UHD 630 核显加速。普通被动式 DP 转 HDMI 不保证可用。
