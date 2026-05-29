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

当前 `13.7.8` EFI 以稳定亮屏和安装为优先，保留 `-igfxvesa`，UHD 630 暂未开启完整硬件加速。
