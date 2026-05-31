# EFI 版本说明

这里保存不同 macOS 版本和显示模式的 OpenCore EFI。

## 目录结构

```text
all_efi
├── safe
│   ├── 12.7.6
│   │   └── EFI
│   └── 13.7.8
│       └── EFI
└── igpu
    ├── 12.7.6
    │   └── EFI
    └── 13.7.8
        └── EFI
```

## 版本选择

| 目录 | macOS | 模式 | 适合场景 |
| --- | --- | --- | --- |
| `igpu/13.7.8/EFI` | Ventura 13.7.8 | 核显加速 | 推荐日用；需要 DP 直连或主动式 DP 转 HDMI；已加入 DW1820A 无线支持 |
| `safe/13.7.8/EFI` | Ventura 13.7.8 | 安全亮屏 | 推荐安装、救援、黑屏恢复；已加入 DW1820A 无线支持 |
| `igpu/12.7.6/EFI` | Monterey 12.7.6 | 核显加速 | 历史备用；需要 DP 直连或主动式 DP 转 HDMI |
| `safe/12.7.6/EFI` | Monterey 12.7.6 | 安全亮屏 | 历史备用、救援 |

## 模式区别

`safe` 目录保留：

```text
-igfxvesa
```

这个参数更容易亮屏，但没有完整 UHD 630 核显加速，系统里可能显示几 MB 显存，动画也会卡顿。

`igpu` 目录删除了 `-igfxvesa`，用于开启 UHD 630 核显加速。已验证：

- DP 直连 DP 显示器可用。
- 主动式 DP 转 HDMI 可用。
- 普通被动式 DP 转 HDMI 不保证可用。

## 无线网卡

Ventura 13.7.8 的两套 EFI 已验证 Dell DW1820A / Broadcom BCM94350ZAE 可用，包含：

- `AirportBrcmFixup.kext`
- `BlueToolFixup.kext`
- `BrcmFirmwareData.kext`
- `BrcmPatchRAM3.kext`

对应 `boot-args` 已加入 `brcmfx-country=#a brcmfx-aspm=0 brcmfx-driver=2`。如果蓝牙不可用，优先检查网卡蓝牙对应的 USB 端口映射。

公开版已经清理个人 SMBIOS 信息。使用前请重新生成并填写：

- `SystemSerialNumber`
- `MLB`
- `SystemUUID`
- `ROM`
