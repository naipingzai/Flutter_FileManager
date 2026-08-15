#!/usr/bin/env bash
# ============================================================
# fetch_deps.sh —— 从 Flutter_CrossPlatformDependency 拉取各平台 FFmpeg 产物并替换
#
# 作用：
#   1. 从 dependency 仓库 GitHub Release 下载各平台的 ffmpeg tarball
#   2. 解压后覆盖本工程 third_party/<platform>/（仅 FFmpeg 相关 .a + 头文件）
#   3. 校验：文件存在、非空
#
# 用法：
#   bash scripts/fetch_deps.sh                # 更新所有平台
#   bash scripts/fetch_deps.sh android        # 仅更新指定平台
#
# 依赖：curl、tar
# ============================================================
set -euo pipefail

# ---- 配置项 ----
# dependency 仓库
REPO="naipingzai/Flutter_CrossPlatformDependency"
BASE="https://github.com/${REPO}/releases/download"

# 本工程 native/third_party 根（第三方预编译库所在）
THIRD_PARTY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../native/third_party" && pwd)"

# 平台 -> release tag（dependency 仓库每个平台一个 tag）
PLATFORM_TAG=(
  linux
  windows
  macos
  android
  ios
)

# ffmpeg 静态库清单（仅替换这些，保留 miniz/stb_image/sqlite 等）
FFMPEG_LIBS=(libavcodec.a libavfilter.a libavformat.a libavutil.a libswscale.a libswresample.a)

# ---- 工具 ----
log() { echo "[fetch_deps] $*"; }
die() { echo "[fetch_deps] 错误：$*" >&2; exit 1; }

# ---- 下载并替换单个平台 ----
fetch_platform() {
  local plat="$1"
  local dir="$THIRD_PARTY/$plat"
  mkdir -p "$dir"

  local tmp; tmp="$(mktemp -d)"
  local tarball="$tmp/ffmpeg.tar.gz"
  local url="${BASE}/${plat}/${plat}-ffmpeg.tar.gz"

  log "下载 $plat: $url"
  curl -fL --retry 3 --retry-delay 2 --max-time 300 -o "$tarball" "$url" \
    || die "下载失败: $url"
  [ -s "$tarball" ] || die "$plat 产物为空"

  tar -xzf "$tarball" -C "$tmp" || die "$plat 解压失败"
  local srclib="$tmp/lib"
  [ -d "$srclib" ] || die "$plat 产物缺少 lib/ 目录"

  # 校验每个 FFmpeg 库存在且非空
  local missing=0 lib
  for lib in "${FFMPEG_LIBS[@]}"; do
    if [ ! -s "$srclib/$lib" ]; then
      log "警告: $plat 缺少 $lib"
      missing=$((missing+1))
    fi
  done
  [ "$missing" -eq 0 ] || die "$plat FFmpeg 库不完整"

  # 覆盖替换：清空旧的 ffmpeg 库，复制新库
  for lib in "${FFMPEG_LIBS[@]}"; do
    rm -f "$dir/lib/$lib"
    cp "$srclib/$lib" "$dir/lib/$lib"
  done
  # 头文件合并：FFmpeg 产物 include/ 只含 ffmpeg 的头文件，
  # 必须保留本工程已有的其它库头文件（miniz.h / stb_image.h / sqlite3.h 等）。
  # 先删除旧的 ffmpeg 头文件目录，再复制新的，避免残留旧版本。
  mkdir -p "$dir/include"
  for old in libavcodec libavfilter libavformat libavutil libswscale libswresample; do
    rm -rf "$dir/include/$old"
  done
  if [ -d "$tmp/include" ]; then
    cp -a "$tmp/include/." "$dir/include/"
  fi

  # 提示 Android 需 PIC（链接进 libfileops.so 的要求，由 dependency 仓库脚本保证）
  [ "$plat" = "android" ] && log "注: Android 库须为 PIC（供 libfileops.so 链接）"

  rm -rf "$tmp"
  log "完成: $plat"
}

# ---- 主流程 ----
if [ "$#" -gt 0 ]; then
  fetch_platform "$1"
else
  for p in "${PLATFORM_TAG[@]}"; do
    fetch_platform "$p"
  done
fi
log "全部完成"
