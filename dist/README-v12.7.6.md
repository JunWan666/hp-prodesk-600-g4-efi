# HP ProDesk 600 G4 DM OpenCore EFI - Monterey 12.7.6

## 本 Release 附件

| 文件 | 模式 | 适合场景 |
| --- | --- | --- |
| `hp-prodesk-600-g4-dm-monterey-12.7.6-igpu.zip` | 核显加速 | 备用日用；需要 DP 直连显示器，或主动式 DP 转 HDMI |
| `hp-prodesk-600-g4-dm-monterey-12.7.6-safe.zip` | 安全亮屏 | 历史备用、救援、排查显示输出问题 |

## 选择建议

- 日常优先建议使用 Ventura 13.7.8。
- 确实需要 Monterey 12.7.6，并且显示连接满足条件：可用 `igpu`。
- 不确定线材、启动黑屏、需要救援：先用 `safe`。
- `safe` 保留 `-igfxvesa`，容易亮屏，但没有完整 UHD 630 加速。
- `igpu` 删除 `-igfxvesa`，用于开启 UHD 630 加速。

## 使用前注意

公开版已经清理个人 SMBIOS 信息。使用前必须重新生成并填写 `SystemSerialNumber`、`MLB`、`SystemUUID` 和 `ROM`。
