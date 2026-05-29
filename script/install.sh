#!/bin/sh
set -eu

DEFAULT_LOCAL_EFI="./all_efi/safe/13.7.8/EFI"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET="$(printf '\033[0m')"
  C_BOLD="$(printf '\033[1m')"
  C_DIM="$(printf '\033[2m')"
  C_RED="$(printf '\033[31m')"
  C_GREEN="$(printf '\033[32m')"
  C_YELLOW="$(printf '\033[33m')"
  C_BLUE="$(printf '\033[34m')"
  C_CYAN="$(printf '\033[36m')"
else
  C_RESET=""
  C_BOLD=""
  C_DIM=""
  C_RED=""
  C_GREEN=""
  C_YELLOW=""
  C_BLUE=""
  C_CYAN=""
fi

say() {
  printf '%s\n' "$*"
}

info() {
  printf '%s%s%s %s\n' "$C_BLUE" "==>" "$C_RESET" "$*"
}

ok() {
  printf '%s%s%s %s\n' "$C_GREEN" "OK" "$C_RESET" "$*"
}

warn() {
  printf '%s%s%s %s\n' "$C_YELLOW" "!!" "$C_RESET" "$*" >&2
}

die() {
  printf '%s%s%s %s\n' "$C_RED" "错误：" "$C_RESET" "$*" >&2
  exit 1
}

banner() {
  printf '%s' "${C_CYAN}${C_BOLD}"
  say "╔══════════════════════════════════════════════════════╗"
  say "║        HP ProDesk 600 G4 DM OpenCore Installer       ║"
  say "╚══════════════════════════════════════════════════════╝"
  say "${C_RESET}${C_DIM}将 BOOT / OC 复制到内置硬盘 EFI，保留 EFI/APPLE。${C_RESET}"
  say
}

usage() {
  cat <<'EOF'
用法：
  sh ./script/install.sh <内置硬盘 EFI 分区标识> [来源 EFI 目录] [--yes]

示例：
  diskutil list
  sh ./script/install.sh disk0s1
  sh ./script/install.sh disk0s1 /Volumes/EFI/EFI
  sh ./script/install.sh disk0s1 ./all_efi/safe/13.7.8/EFI
  sh ./script/install.sh disk0s1 ./all_efi/igpu/13.7.8/EFI

在线执行：
  curl -fsSL https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install.sh | sh -s -- disk0s1

说明：
  - 第一个参数是目标，也就是内置硬盘的 EFI 分区，例如 disk0s1。
  - 第二个参数可以省略；脚本会自动查找包含 BOOT 和 OC 的来源 EFI。
  - 如果 U 盘 EFI 分区没有挂载，脚本会尝试挂载外置磁盘里的 EFI 分区。
  - 目标里已有 BOOT 或 OC 时会先备份，再替换。
  - EFI/APPLE 会被保留，不影响 macOS 安装器自己的文件。
  - 加 --yes 可以跳过安装前确认。
EOF
}

is_valid_efi_dir() {
  [ -d "$1/BOOT" ] && [ -d "$1/OC" ]
}

strip_trailing_slash() {
  case "$1" in
    /) printf '%s\n' "/" ;;
    *) printf '%s\n' "${1%/}" ;;
  esac
}

canonical_dir() {
  (cd "$1" 2>/dev/null && pwd -P) || printf '%s\n' "$1"
}

disk_mount_point() {
  diskutil info "$1" 2>/dev/null | awk -F': *' '/Mount Point/ {print $2; exit}'
}

mount_external_efi_partitions() {
  command -v diskutil >/dev/null 2>&1 || return 0

  ids="$(diskutil list external physical 2>/dev/null | awk '/ EFI / && $NF ~ /^disk[0-9]+s[0-9]+$/ {print $NF}')"
  [ -n "$ids" ] || return 0

  for id in $ids; do
    mount_point="$(disk_mount_point "$id" || true)"
    if [ -z "$mount_point" ] || [ "$mount_point" = "Not mounted" ]; then
      warn "尝试挂载外置 EFI 分区：$id"
      sudo diskutil mount "$id" >/dev/null 2>&1 || true
    fi
  done
}

source_candidates() {
  target_mount="$1"

  for d in \
    "$PWD/$DEFAULT_LOCAL_EFI" \
    "$PWD/EFI" \
    "$DEFAULT_LOCAL_EFI" \
    "./EFI" \
    /Volumes/*/EFI \
    /Volumes/*; do
    [ -d "$d" ] || continue
    is_valid_efi_dir "$d" || continue
    d="$(canonical_dir "$d")"

    if [ -n "$target_mount" ]; then
      case "$d" in
        "$target_mount"/EFI|"$target_mount"/EFI/*) continue ;;
      esac
    fi

    printf '%s\n' "$d"
  done | awk '!seen[$0]++'
}

print_candidates() {
  candidates="$1"
  printf '%s\n' "$candidates" | sed '/^$/d' | awk '{printf "  - %s\n", $0}'
}

resolve_source_efi() {
  input="$1"
  target_mount="$2"

  if [ -n "$input" ]; then
    input="$(strip_trailing_slash "$input")"

    if is_valid_efi_dir "$input"; then
      canonical_dir "$input"
      return 0
    fi

    if [ -d "$input/EFI" ] && is_valid_efi_dir "$input/EFI"; then
      canonical_dir "$input/EFI"
      return 0
    fi

    warn "指定的来源 EFI 不完整：$input"
    warn "脚本会改为自动查找包含 BOOT 和 OC 的 EFI。"
  fi

  mount_external_efi_partitions

  candidates="$(source_candidates "$target_mount")"
  count="$(printf '%s\n' "$candidates" | sed '/^$/d' | wc -l | tr -d ' ')"

  case "$count" in
    0)
      die "没有找到来源 EFI。请先挂载 U 盘 EFI 分区，或手动传入类似 /Volumes/EFI/EFI 的路径。"
      ;;
    1)
      printf '%s\n' "$candidates" | sed -n '1p'
      ;;
    *)
      warn "找到多个可能的来源 EFI，脚本不自动猜。请重新执行并指定其中一个路径："
      print_candidates "$candidates" >&2
      exit 1
      ;;
  esac
}

confirm_or_exit() {
  [ "${ASSUME_YES:-0}" = "1" ] && return 0

  printf '%s' "${C_YELLOW}继续安装？输入 y 确认，其他任意键取消：${C_RESET} "
  if [ -r /dev/tty ]; then
    IFS= read -r answer < /dev/tty || answer=""
  else
    IFS= read -r answer || answer=""
  fi

  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) die "已取消，没有修改目标 EFI。" ;;
  esac
}

warn_if_smbios_placeholder() {
  config="$1/OC/config.plist"
  [ -f "$config" ] || return 0

  if grep -Eq 'CHANGEME_|00000000-0000-0000-0000-000000000000|112233000000' "$config"; then
    warn "来源 EFI 里检测到公开版 SMBIOS 占位值。"
    warn "安装前请确认你已经把 SystemSerialNumber、MLB、SystemUUID、ROM 改成自己的。"
  fi
}

TARGET_EFI_PART=""
SOURCE_EFI_INPUT=""
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -y|--yes)
      ASSUME_YES=1
      ;;
    *)
      if [ -z "$TARGET_EFI_PART" ]; then
        TARGET_EFI_PART="$1"
      elif [ -z "$SOURCE_EFI_INPUT" ]; then
        SOURCE_EFI_INPUT="$1"
      else
        die "参数太多：$1"
      fi
      ;;
  esac
  shift
done

banner

if [ -z "$TARGET_EFI_PART" ]; then
  usage
  die "请先指定内置硬盘 EFI 分区，例如 disk0s1。"
fi

command -v diskutil >/dev/null 2>&1 || die "没有找到 diskutil。这个脚本需要在 macOS 里执行。"
command -v ditto >/dev/null 2>&1 || die "没有找到 ditto。这个脚本需要在 macOS 里执行。"

TARGET_MOUNT_BEFORE="$(disk_mount_point "$TARGET_EFI_PART" || true)"
if [ "$TARGET_MOUNT_BEFORE" = "Not mounted" ]; then
  TARGET_MOUNT_BEFORE=""
fi

SOURCE_EFI="$(resolve_source_efi "$SOURCE_EFI_INPUT" "$TARGET_MOUNT_BEFORE")"
warn_if_smbios_placeholder "$SOURCE_EFI"

info "安装信息"
say "  目标 EFI 分区：${C_BOLD}$TARGET_EFI_PART${C_RESET}"
say "  来源 EFI 目录：${C_BOLD}$SOURCE_EFI${C_RESET}"
say

confirm_or_exit

info "挂载目标 EFI 分区：$TARGET_EFI_PART"
sudo diskutil mount "$TARGET_EFI_PART" >/dev/null

MOUNT_POINT="$(disk_mount_point "$TARGET_EFI_PART" || true)"
if [ -z "$MOUNT_POINT" ] || [ "$MOUNT_POINT" = "Not mounted" ]; then
  die "无法识别 $TARGET_EFI_PART 的挂载路径。"
fi

case "$SOURCE_EFI" in
  "$MOUNT_POINT"/EFI|"$MOUNT_POINT"/EFI/*)
    die "来源 EFI 和目标 EFI 是同一个位置，已停止。"
    ;;
esac

ok "目标 EFI 已挂载到：$MOUNT_POINT"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$MOUNT_POINT/EFI/backup-before-opencore-$STAMP"

sudo mkdir -p "$MOUNT_POINT/EFI"

if [ -d "$MOUNT_POINT/EFI/BOOT" ] || [ -d "$MOUNT_POINT/EFI/OC" ]; then
  info "备份已有 BOOT/OC 到：$BACKUP_DIR"
  sudo mkdir -p "$BACKUP_DIR"
  if [ -d "$MOUNT_POINT/EFI/BOOT" ]; then
    sudo ditto "$MOUNT_POINT/EFI/BOOT" "$BACKUP_DIR/BOOT"
  fi
  if [ -d "$MOUNT_POINT/EFI/OC" ]; then
    sudo ditto "$MOUNT_POINT/EFI/OC" "$BACKUP_DIR/OC"
  fi
else
  ok "目标 EFI 里还没有 BOOT/OC，不需要备份。"
fi

info "复制 BOOT 和 OC"
sudo ditto "$SOURCE_EFI/BOOT" "$MOUNT_POINT/EFI/BOOT"
sudo ditto "$SOURCE_EFI/OC" "$MOUNT_POINT/EFI/OC"
sync

say
ok "安装完成。内置 EFI 当前内容："
ls -la "$MOUNT_POINT/EFI"
say
say "${C_GREEN}${C_BOLD}完成。${C_RESET}现在可以关机、拔掉 U 盘，然后测试内置硬盘引导。"
