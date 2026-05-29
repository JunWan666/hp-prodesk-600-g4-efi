# HP ProDesk 600 G4 DM OpenCore EFI - Monterey 12.7.6

这是 HP ProDesk 600 G4 Desktop Mini 的 macOS Monterey 12.7.6 OpenCore EFI，主要作为历史备用版本保留。如果没有特殊需求，日常更建议优先使用 Ventura 13.7.8。

## 适用硬件

| 项目 | 配置 |
| --- | --- |
| 机型 | HP ProDesk 600 G4 Desktop Mini |
| CPU | Intel Core i3-9100T |
| 核显 | Intel UHD Graphics 630 |
| 有线网卡 | Intel I219-LM |
| 声卡 | Conexant，当前使用 `alcid=23` |
| SMBIOS | `Macmini8,1` |

同为 HP ProDesk 600 G4 DM，也可能因为 CPU、网卡、无线网卡、显示输出模块不同而需要调整。不同硬件请先备份原 EFI 再测试。

## 本 Release 附件

| 文件 | 模式 | 适合场景 |
| --- | --- | --- |
| `hp-prodesk-600-g4-dm-monterey-12.7.6-igpu.zip` | 核显加速版 | 备用日用；需要 DP 直连显示器，或主动式 DP 转 HDMI |
| `hp-prodesk-600-g4-dm-monterey-12.7.6-safe.zip` | 安全亮屏版 | 历史备用、黑屏救援、排查显示输出问题 |

## 怎么选择

优先建议：

- 日常优先使用 Ventura 13.7.8。
- 确实需要 Monterey 12.7.6，并且有 DP 显示器或主动式 DP 转 HDMI：下载 `igpu`。
- 不确定线材、启动后黑屏、需要救援：下载 `safe`。
- 普通被动式 DP 转 HDMI 线不保证可用。表现可能是跑码后无信号，或者进入系统黑屏。

两个包的核心区别：

- `safe` 保留 `-igfxvesa`，更容易亮屏，但没有完整 UHD 630 核显加速，系统可能显示几 MB 显存，动画会卡顿。
- `igpu` 删除 `-igfxvesa`，用于开启 UHD 630 核显加速。

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

如果你已经能通过 U 盘进入 macOS，可以用仓库脚本把当前 U 盘 EFI 复制到内置硬盘 EFI 分区。先在 macOS 里确认磁盘：

```bash
diskutil list
```

通常内置硬盘 EFI 是 `disk0s1`。确认后执行：

```bash
curl -fsSL https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install.sh | sh -s -- disk0s1
```

脚本会备份内置硬盘已有的 `EFI/BOOT` 和 `EFI/OC`，再复制当前可用的 EFI。

## 核显加速和显示线材

`igpu` 版本用于开启 UHD 630 核显加速。已验证：

- DP 直连 DP 显示器可用。
- 主动式 DP 转 HDMI 可用。

不建议使用普通被动式 DP 转 HDMI 线。选购转接器时优先看是否标注 `Active`、`主动式`、`DP 1.2 to HDMI 2.0`、`4K60`。

## 黑屏恢复

如果使用 `igpu` 后黑屏：

1. 先换回 `safe` 版本启动。
2. 或者把 `EFI/OC/config.plist` 里的 `boot-args` 加回 `-igfxvesa`。
3. 进入 OpenCore 后执行一次 `Reset NVRAM`。
4. 确认线材是 DP 直连或主动式 DP 转 HDMI。

## 已知情况

- Monterey 12.7.6 是历史成功配置。
- 有线网卡可用。
- USB 鼠标键盘可用。
- UHD 630 核显加速在 DP 直连和主动式 DP 转 HDMI 下可用。
- 声音使用 `alcid=23`，不同机器可能需要自行复测。

## SHA256

```text
37095a2acdb4def09818ca89914d5511a303e6c903e6da81f89b1c9f32dc72a9  hp-prodesk-600-g4-dm-monterey-12.7.6-igpu.zip
6e3ea810626066d612f714cab76c0e50b1fbc0b49e9c44517070d4892312caf2  hp-prodesk-600-g4-dm-monterey-12.7.6-safe.zip
```

## 免责声明

本 Release 仅提供 OpenCore 配置学习与备份。macOS 版权归 Apple 所有，请自行遵守所在地区法律法规和 Apple 软件许可协议。
