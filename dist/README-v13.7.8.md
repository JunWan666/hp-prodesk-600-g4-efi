# HP ProDesk 600 G4 DM OpenCore EFI - Ventura 13.7.8

## 本 Release 附件

| 文件 | 模式 | 适合场景 |
| --- | --- | --- |
| `hp-prodesk-600-g4-dm-ventura-13.7.8-igpu.zip` | 核显加速 | 推荐日用；需要 DP 直连显示器，或主动式 DP 转 HDMI |
| `hp-prodesk-600-g4-dm-ventura-13.7.8-safe.zip` | 安全亮屏 | 首次安装、黑屏救援、排查显示输出问题 |

## 选择建议

- 有 DP 显示器，或确认是主动式 DP 转 HDMI：优先用 `igpu`。
- 普通 DP 转 HDMI 线、安装阶段、黑屏恢复：先用 `safe`。
- `safe` 保留 `-igfxvesa`，容易亮屏，但没有完整 UHD 630 加速。
- `igpu` 删除 `-igfxvesa`，用于开启 UHD 630 加速。

## 已验证

- macOS Ventura 13.7.8 可进入系统。
- DP 直连显示器可开启 UHD 630 核显加速。
- 主动式 DP 转 HDMI 可用。
- OpenCore 版本：1.0.7。

## 使用前注意

公开版已经清理个人 SMBIOS 信息。使用前必须重新生成并填写 `SystemSerialNumber`、`MLB`、`SystemUUID` 和 `ROM`。
