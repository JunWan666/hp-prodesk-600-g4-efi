#!/bin/sh
set -eu

VERSION_TAG="v13.7.8"
REPO_URL="https://github.com/JunWan666/hp-prodesk-600-g4-efi"
RAW_BASE_URL="https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main"
IGPU_ZIP="hp-prodesk-600-g4-dm-ventura-13.7.8-igpu.zip"
SAFE_ZIP="hp-prodesk-600-g4-dm-ventura-13.7.8-safe.zip"

TEMP_DIRS=""

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

cleanup() {
  for d in $TEMP_DIRS; do
    [ -n "$d" ] && [ -d "$d" ] && rm -rf "$d"
  done
}

trap cleanup EXIT
trap 'cleanup; exit 130' HUP INT TERM

say() {
  printf '%s\n' "$*"
}

say_err() {
  printf '%s\n' "$*" >&2
}

info() {
  printf '%s%s%s %s\n' "$C_BLUE" "==>" "$C_RESET" "$*"
}

ok() {
  printf '%s%s%s  %s\n' "$C_GREEN" "OK" "$C_RESET" "$*"
}

warn() {
  printf '%s%s%s  %s\n' "$C_YELLOW" "!!" "$C_RESET" "$*" >&2
}

die() {
  printf '%s%s%s %s\n' "$C_RED" "错误：" "$C_RESET" "$*" >&2
  exit 1
}

rule() {
  say "${C_DIM}──────────────────────────────────────────────────────────────${C_RESET}"
}

section() {
  say
  rule
  say "  ${C_BOLD}$1${C_RESET}"
  rule
}

banner() {
  printf '%s' "${C_CYAN}${C_BOLD}"
  say "╭────────────────────────────────────────────────────────────╮"
  say "│  HP ProDesk 600 G4 DM                                      │"
  say "│  OpenCore EFI Installer                                    │"
  say "│  Ventura 13.7.8 · safe / igpu · DW1820A Wi-Fi Ready        │"
  say "╰────────────────────────────────────────────────────────────╯"
  printf '%s' "$C_RESET"
  say
}

usage() {
  cat <<'EOF'
用法：
  sh ./script/install.sh
  sh ./script/install.sh <内置硬盘 EFI 分区标识> [来源 EFI 目录] [--yes]

示例：
  sh ./script/install.sh
  sh ./script/install.sh disk0s1
  sh ./script/install.sh disk0s1 /Volumes/EFI/EFI
  sh ./script/install.sh disk0s1 ./all_efi/igpu/13.7.8/EFI
  sh ./script/install.sh disk0s1 ./all_efi/safe/13.7.8/EFI --yes

在线执行：
  curl -fsSL https://raw.githubusercontent.com/JunWan666/hp-prodesk-600-g4-efi/main/script/install.sh | sh

说明：
  - 不传参数时，脚本会自动识别唯一的内置硬盘 EFI 分区。
  - 菜单里默认选择当前 U 盘 EFI，直接回车即可。
  - 确认安装时默认继续，直接回车等同于 Y。
  - 如果 U 盘没插或没找到外置 EFI，可以从 GitHub 下载 igpu / safe 版。
  - 目标里已有 BOOT 或 OC 时会先备份，再替换。
  - EFI/APPLE 会被保留，不影响 macOS 安装器自己的文件。
EOF
}

have_tty() {
  [ -r /dev/tty ] && [ -w /dev/tty ]
}

ask() {
  prompt_text="$1"

  if have_tty; then
    printf '%s' "$prompt_text" > /dev/tty
    IFS= read -r answer < /dev/tty || answer=""
  else
    printf '%s' "$prompt_text" >&2
    IFS= read -r answer || answer=""
  fi

  printf '%s\n' "$answer"
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

internal_efi_partitions() {
  diskutil list internal physical 2>/dev/null | awk '/ EFI / && $NF ~ /^disk[0-9]+s[0-9]+$/ {print $NF}'
}

target_internal_flag() {
  diskutil info "$1" 2>/dev/null | awk -F': *' '
    /Internal/ {print $2; exit}
    /Device Location/ {
      if ($2 == "Internal") print "Yes"
      else if ($2 == "External") print "No"
      exit
    }
  '
}

is_detected_internal_efi() {
  internal_efi_partitions | awk -v target="$1" '$0 == target {found = 1} END {exit found ? 0 : 1}'
}

ensure_target_is_internal() {
  if is_detected_internal_efi "$1"; then
    return 0
  fi

  flag="$(target_internal_flag "$1" || true)"

  case "$flag" in
    Yes) return 0 ;;
    No) die "$1 不是内置硬盘分区，已停止。请不要把目标选成 U 盘。" ;;
    *) warn "无法确认 $1 是否为内置分区，请确认它是内置硬盘 EFI。" ;;
  esac
}

auto_detect_target_efi() {
  ids="$(internal_efi_partitions || true)"
  count="$(printf '%s\n' "$ids" | sed '/^$/d' | wc -l | tr -d ' ')"

  case "$count" in
    0)
      warn "没有自动找到内置硬盘 EFI 分区。"
      say_err
      say_err "请先执行："
      say_err "  diskutil list"
      say_err
      say_err "然后手动指定，例如："
      say_err "  sh ./script/install.sh disk0s1"
      exit 1
      ;;
    1)
      printf '%s\n' "$ids" | sed -n '1p'
      ;;
    *)
      warn "检测到多个内置 EFI 分区，脚本无法安全判断目标。"
      printf '%s\n' "$ids" | awk '{printf "  - %s\n", $0}' >&2
      say_err
      say_err "请手动指定目标，例如："
      say_err "  sh ./script/install.sh disk0s1"
      exit 1
      ;;
  esac
}

mount_target_efi() {
  target_part="$1"

  mount_point="$(disk_mount_point "$target_part" || true)"
  if [ "$mount_point" = "Not mounted" ]; then
    mount_point=""
  fi

  if [ -z "$mount_point" ]; then
    sudo diskutil mount "$target_part" >/dev/null
    mount_point="$(disk_mount_point "$target_part" || true)"
  fi

  if [ -z "$mount_point" ] || [ "$mount_point" = "Not mounted" ]; then
    die "无法识别 $target_part 的挂载路径。"
  fi

  printf '%s\n' "$mount_point"
}

mount_external_efi_partitions() {
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

usb_source_candidates() {
  target_mount="$1"

  mount_external_efi_partitions

  {
    ids="$(diskutil list external physical 2>/dev/null | awk '/ EFI / && $NF ~ /^disk[0-9]+s[0-9]+$/ {print $NF}')"

    for id in $ids; do
      mount_point="$(disk_mount_point "$id" || true)"
      [ -n "$mount_point" ] || continue
      [ "$mount_point" = "Not mounted" ] && continue

      for d in "$mount_point/EFI" "$mount_point"; do
        [ -d "$d" ] || continue
        is_valid_efi_dir "$d" || continue
        d="$(canonical_dir "$d")"

        case "$d" in
          "$target_mount"|"$target_mount"/EFI|"$target_mount"/EFI/*) continue ;;
        esac

        printf '%s\n' "$d"
      done
    done

    for mount_point in /Volumes/*; do
      [ -d "$mount_point" ] || continue

      for d in "$mount_point/EFI" "$mount_point"; do
        [ -d "$d" ] || continue
        is_valid_efi_dir "$d" || continue
        d="$(canonical_dir "$d")"

        case "$d" in
          "$target_mount"|"$target_mount"/EFI|"$target_mount"/EFI/*) continue ;;
        esac

        printf '%s\n' "$d"
      done
    done
  } | awk '!seen[$0]++'
}

print_candidates() {
  candidates="$1"
  printf '%s\n' "$candidates" | sed '/^$/d' | awk '{printf "  - %s\n", $0}'
}

choose_usb_source() {
  candidates="$(usb_source_candidates "$TARGET_MOUNT" || true)"
  count="$(printf '%s\n' "$candidates" | sed '/^$/d' | wc -l | tr -d ' ')"

  case "$count" in
    0)
      warn "没有找到当前 U 盘 EFI。"
      warn "请确认 U 盘已插入，并且 EFI 分区里存在 EFI/BOOT 和 EFI/OC。"
      return 1
      ;;
    1)
      SOURCE_EFI="$(printf '%s\n' "$candidates" | sed -n '1p')"
      SOURCE_MODE="当前 U 盘 EFI"
      return 0
      ;;
    *)
      warn "检测到多个外置 EFI，脚本不自动猜。请拔掉多余 U 盘，或选择手动输入路径。"
      print_candidates "$candidates" >&2
      return 1
      ;;
  esac
}

verify_download_hash() {
  zip_path="$1"
  zip_name="$2"
  tmp_dir="$3"

  if ! command -v shasum >/dev/null 2>&1; then
    warn "没有找到 shasum，跳过 SHA256 校验。"
    return 0
  fi

  sums_path="$tmp_dir/SHA256SUMS.txt"
  if ! curl -fsL -o "$sums_path" "$RAW_BASE_URL/dist/SHA256SUMS.txt"; then
    warn "无法下载 SHA256SUMS.txt，跳过 SHA256 校验。"
    return 0
  fi

  expected="$(awk -v f="$zip_name" '$2 == f {print $1; exit}' "$sums_path")"
  if [ -z "$expected" ]; then
    warn "SHA256SUMS.txt 里没有找到 $zip_name。"
    return 1
  fi

  actual="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
  if [ "$actual" != "$expected" ]; then
    warn "SHA256 校验不一致。"
    warn "期望：$expected"
    warn "实际：$actual"
    return 1
  fi

  ok "SHA256 校验通过"
  return 0
}

download_verified_zip() {
  zip_name="$1"
  zip_path="$2"
  tmp_dir="$3"

  release_url="$REPO_URL/releases/download/$VERSION_TAG/$zip_name"
  raw_url="$RAW_BASE_URL/dist/$zip_name"

  info "下载 GitHub Release：$zip_name"
  if curl -fsSL --retry 3 --connect-timeout 20 -o "$zip_path" "$release_url"; then
    if verify_download_hash "$zip_path" "$zip_name" "$tmp_dir"; then
      return 0
    fi
    warn "Release 附件可能还没更新，改用 main 分支 dist 包。"
  else
    warn "Release 下载失败，改用 main 分支 dist 包。"
  fi

  rm -f "$zip_path"
  info "下载 main 分支 dist：$zip_name"
  if ! curl -fsSL --retry 3 --connect-timeout 20 -o "$zip_path" "$raw_url"; then
    warn "GitHub 下载失败。请检查网络，或先用 U 盘 EFI 安装。"
    return 1
  fi

  verify_download_hash "$zip_path" "$zip_name" "$tmp_dir"
}

choose_github_source() {
  mode="$1"

  command -v curl >/dev/null 2>&1 || {
    warn "没有找到 curl，无法从 GitHub 下载。"
    return 1
  }

  command -v unzip >/dev/null 2>&1 || {
    warn "没有找到 unzip，无法解压 GitHub ZIP。"
    return 1
  }

  case "$mode" in
    igpu)
      zip_name="$IGPU_ZIP"
      SOURCE_MODE="GitHub · Ventura 13.7.8 · igpu 核显加速版"
      ;;
    safe)
      zip_name="$SAFE_ZIP"
      SOURCE_MODE="GitHub · Ventura 13.7.8 · safe 安全亮屏版"
      ;;
    *)
      warn "未知 GitHub 模式：$mode"
      return 1
      ;;
  esac

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/hp-prodesk-efi.XXXXXX")"
  TEMP_DIRS="$TEMP_DIRS $tmp_dir"
  zip_path="$tmp_dir/$zip_name"
  unzip_dir="$tmp_dir/unzip"

  if ! download_verified_zip "$zip_name" "$zip_path" "$tmp_dir"; then
    return 1
  fi

  mkdir -p "$unzip_dir"
  if ! unzip -q "$zip_path" -d "$unzip_dir"; then
    warn "ZIP 解压失败：$zip_name"
    return 1
  fi

  SOURCE_EFI="$unzip_dir/EFI"
  if ! is_valid_efi_dir "$SOURCE_EFI"; then
    warn "下载的 ZIP 里没有找到完整的 EFI/BOOT 和 EFI/OC。"
    return 1
  fi

  ok "已验证 EFI/BOOT 和 EFI/OC"
  return 0
}

resolve_source_path() {
  input="$1"
  input="$(strip_trailing_slash "$input")"

  if is_valid_efi_dir "$input"; then
    canonical_dir "$input"
    return 0
  fi

  if [ -d "$input/EFI" ] && is_valid_efi_dir "$input/EFI"; then
    canonical_dir "$input/EFI"
    return 0
  fi

  return 1
}

choose_manual_source() {
  input="$(ask "请输入 EFI 路径：")"
  [ -n "$input" ] || {
    warn "没有输入路径。"
    return 1
  }

  if SOURCE_EFI="$(resolve_source_path "$input")"; then
    SOURCE_MODE="手动指定 EFI"
    return 0
  fi

  warn "这个路径不是完整 EFI：$input"
  warn "需要包含 BOOT 和 OC，例如 /Volumes/EFI/EFI。"
  return 1
}

source_menu() {
  while :; do
    section "选择 EFI 来源"
    say "  ${C_GREEN}${C_BOLD}[默认]${C_RESET}  1. 使用当前 U 盘 EFI"
    say "              已经用这个 U 盘成功进系统时，选这个最稳"
    say
    say "          2. GitHub · Ventura 13.7.8 · igpu 核显加速版"
    say "              DP 直连 / 主动式 DP 转 HDMI，日常使用推荐"
    say "              包含：UHD 630 加速 + DW1820A Wi-Fi；蓝牙待修"
    say
    say "          3. GitHub · Ventura 13.7.8 · safe 安全亮屏版"
    say "              首次安装、黑屏救援、显示器线材不确定"
    say "              包含：安全亮屏 + DW1820A Wi-Fi；蓝牙待修"
    say
    say "          4. 手动输入 EFI 路径"
    say
    say "          0. 退出"
    say

    choice="$(ask "请选择 EFI 来源 [1]：")"
    [ -n "$choice" ] || choice="1"

    case "$choice" in
      1)
        choose_usb_source && return 0
        ;;
      2)
        choose_github_source igpu && return 0
        ;;
      3)
        choose_github_source safe && return 0
        ;;
      4)
        choose_manual_source && return 0
        ;;
      0)
        say "已退出，没有修改目标 EFI。"
        exit 0
        ;;
      *)
        warn "无效选择：$choice"
        ;;
    esac
  done
}

confirm_or_exit() {
  [ "${ASSUME_YES:-0}" = "1" ] && return 0

  answer="$(ask "继续安装？[Y/n]：")"
  [ -n "$answer" ] || answer="Y"

  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    n|N|no|NO)
      say "已取消，没有修改目标 EFI。"
      exit 0
      ;;
    *)
      warn "未确认安装，已取消。"
      exit 0
      ;;
  esac
}

warn_if_smbios_placeholder() {
  config="$1/OC/config.plist"
  [ -f "$config" ] || return 0

  if grep -Eq 'CHANGEME_|00000000-0000-0000-0000-000000000000|112233000000' "$config"; then
    warn "来源 EFI 里检测到公开版 SMBIOS 占位值。"
    warn "测试启动可以继续；正式日用前建议填写自己的 SystemSerialNumber、MLB、SystemUUID、ROM。"
  fi
}

ensure_source_not_target() {
  case "$SOURCE_EFI" in
    "$TARGET_MOUNT"/EFI|"$TARGET_MOUNT"/EFI/*)
      die "来源 EFI 和目标 EFI 是同一个位置，已停止。"
      ;;
  esac
}

ensure_safe_target_mount() {
  [ -n "$TARGET_MOUNT" ] || die "目标 EFI 挂载路径为空，已停止。"

  case "$TARGET_MOUNT" in
    /Volumes/*) ;;
    *)
      die "目标 EFI 挂载路径看起来不安全：$TARGET_MOUNT"
      ;;
  esac

  [ -d "$TARGET_MOUNT" ] || die "目标挂载路径不存在：$TARGET_MOUNT"
}

print_install_summary() {
  section "安装确认"
  say "  目标 EFI ：${C_BOLD}$TARGET_EFI_PART${C_RESET}  $TARGET_MOUNT"
  say "  来源 EFI ：${C_BOLD}$SOURCE_EFI${C_RESET}"
  say "  模式     ：$SOURCE_MODE"
  say
  warn "即将替换目标 EFI 里的 BOOT / OC"
  warn "旧 BOOT / OC 会自动备份"
  warn "EFI/APPLE 不会被删除"
  say
}

install_efi() {
  ensure_safe_target_mount

  STAMP="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$TARGET_MOUNT/EFI/backup-before-opencore-$STAMP"

  sudo mkdir -p "$TARGET_MOUNT/EFI"

  if [ -d "$TARGET_MOUNT/EFI/BOOT" ] || [ -d "$TARGET_MOUNT/EFI/OC" ]; then
    info "备份已有 BOOT / OC"
    sudo mkdir -p "$BACKUP_DIR"
    if [ -d "$TARGET_MOUNT/EFI/BOOT" ]; then
      sudo ditto "$TARGET_MOUNT/EFI/BOOT" "$BACKUP_DIR/BOOT"
    fi
    if [ -d "$TARGET_MOUNT/EFI/OC" ]; then
      sudo ditto "$TARGET_MOUNT/EFI/OC" "$BACKUP_DIR/OC"
    fi
    ok "已备份旧引导：$BACKUP_DIR"
  else
    ok "目标 EFI 里还没有 BOOT / OC，不需要备份"
  fi

  info "清理旧 BOOT / OC"
  if [ -d "$TARGET_MOUNT/EFI/BOOT" ]; then
    sudo rm -rf "$TARGET_MOUNT/EFI/BOOT"
  fi
  if [ -d "$TARGET_MOUNT/EFI/OC" ]; then
    sudo rm -rf "$TARGET_MOUNT/EFI/OC"
  fi

  info "复制 BOOT 和 OC"
  sudo ditto "$SOURCE_EFI/BOOT" "$TARGET_MOUNT/EFI/BOOT"
  sudo ditto "$SOURCE_EFI/OC" "$TARGET_MOUNT/EFI/OC"
  sync

  [ -d "$TARGET_MOUNT/EFI/BOOT" ] || die "复制后没有找到目标 BOOT。"
  [ -f "$TARGET_MOUNT/EFI/OC/config.plist" ] || die "复制后没有找到目标 OC/config.plist。"

  section "安装完成"
  ok "已复制 BOOT"
  ok "已复制 OC"
  ok "安装完成"
  say
  say "当前内置 EFI 内容："
  ls -1 "$TARGET_MOUNT/EFI" | sed 's/^/  /' | sort
  say
  say "${C_GREEN}${C_BOLD}完成。${C_RESET}现在可以关机、拔掉 U 盘，然后测试内置硬盘引导。"
}

TARGET_EFI_PART=""
SOURCE_EFI_INPUT=""
SOURCE_EFI=""
SOURCE_MODE=""
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

command -v diskutil >/dev/null 2>&1 || die "没有找到 diskutil。这个脚本需要在 macOS 里执行。"
command -v ditto >/dev/null 2>&1 || die "没有找到 ditto。这个脚本需要在 macOS 里执行。"

if [ -z "$TARGET_EFI_PART" ]; then
  info "自动检测内置硬盘 EFI 分区"
  TARGET_EFI_PART="$(auto_detect_target_efi)"
else
  info "使用指定的内置硬盘 EFI 分区：$TARGET_EFI_PART"
fi

ensure_target_is_internal "$TARGET_EFI_PART"
TARGET_MOUNT="$(mount_target_efi "$TARGET_EFI_PART")"
ok "已找到目标：$TARGET_EFI_PART  $TARGET_MOUNT"
warn "会备份旧 BOOT / OC"
warn "会保留 EFI/APPLE"

if [ -n "$SOURCE_EFI_INPUT" ]; then
  if SOURCE_EFI="$(resolve_source_path "$SOURCE_EFI_INPUT")"; then
    SOURCE_MODE="手动指定 EFI"
  else
    die "指定的来源 EFI 不完整：$SOURCE_EFI_INPUT"
  fi
else
  if have_tty; then
    source_menu
  else
    choose_usb_source || die "非交互环境下没有找到默认 U 盘 EFI。请手动传入来源 EFI 路径。"
  fi
fi

ensure_source_not_target
warn_if_smbios_placeholder "$SOURCE_EFI"
print_install_summary
confirm_or_exit
install_efi
