#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
用法：
  sh ./script/install.sh <内置硬盘EFI分区标识> <EFI目录路径>

示例：
  diskutil list
  sh ./script/install.sh disk0s1 ./all_efi/13.7.8/EFI

在线执行：
  curl -fsSL https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install.sh | sh -s -- disk0s1 /Volumes/OPENCORE/EFI

说明：
  - 脚本会挂载内置硬盘 EFI 分区。
  - 脚本会复制来源 EFI 里的 BOOT 和 OC 到内置硬盘 EFI。
  - 如果目标里已有 BOOT 或 OC，会先备份再替换。
  - 脚本会保留 EFI/APPLE，不影响 macOS 安装器自己的文件。
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ $# -lt 2 ]; then
  usage
  exit 0
fi

TARGET_EFI_PART="$1"
SOURCE_EFI="$2"

if [ ! -d "$SOURCE_EFI/BOOT" ] || [ ! -d "$SOURCE_EFI/OC" ]; then
  echo "来源 EFI 不完整：$SOURCE_EFI" >&2
  echo "应该存在：$SOURCE_EFI/BOOT 和 $SOURCE_EFI/OC" >&2
  exit 1
fi

echo "目标 EFI 分区：$TARGET_EFI_PART"
echo "来源 EFI 目录：$SOURCE_EFI"
echo

echo "正在挂载目标 EFI 分区..."
sudo diskutil mount "$TARGET_EFI_PART" >/dev/null

MOUNT_POINT="$(diskutil info "$TARGET_EFI_PART" | awk -F': *' '/Mount Point/ {print $2; exit}')"
if [ -z "$MOUNT_POINT" ] || [ "$MOUNT_POINT" = "Not mounted" ]; then
  echo "无法识别 $TARGET_EFI_PART 的挂载路径。" >&2
  exit 1
fi

echo "已挂载到：$MOUNT_POINT"
echo

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$MOUNT_POINT/EFI/backup-before-opencore-$STAMP"

sudo mkdir -p "$MOUNT_POINT/EFI"

if [ -d "$MOUNT_POINT/EFI/BOOT" ] || [ -d "$MOUNT_POINT/EFI/OC" ]; then
  echo "正在备份已有 BOOT/OC 到：$BACKUP_DIR"
  sudo mkdir -p "$BACKUP_DIR"
  if [ -d "$MOUNT_POINT/EFI/BOOT" ]; then
    sudo ditto "$MOUNT_POINT/EFI/BOOT" "$BACKUP_DIR/BOOT"
  fi
  if [ -d "$MOUNT_POINT/EFI/OC" ]; then
    sudo ditto "$MOUNT_POINT/EFI/OC" "$BACKUP_DIR/OC"
  fi
fi

echo "正在复制 BOOT 和 OC..."
sudo ditto "$SOURCE_EFI/BOOT" "$MOUNT_POINT/EFI/BOOT"
sudo ditto "$SOURCE_EFI/OC" "$MOUNT_POINT/EFI/OC"
sync

echo
echo "安装后的内置 EFI 内容："
ls -la "$MOUNT_POINT/EFI"
echo
echo "完成。现在可以关机、拔掉 U 盘，然后测试内置硬盘引导。"
