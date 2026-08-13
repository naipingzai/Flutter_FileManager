#!/bin/bash
# ============================================================
# 下载 FFmpeg 源码（固定版本 4.4.4，与本地已验证构建一致）
# 供各平台构建脚本共用。若源码已存在则跳过。
# ============================================================
set -e

FFMPEG_VERSION="4.4.4"
FFMPEG_DIR="${1:?usage: fetch_ffmpeg.sh <ffmpeg_dir>}"

if [ -f "$FFMPEG_DIR/configure" ]; then
    echo "FFmpeg 源码已存在: $FFMPEG_DIR"
    exit 0
fi

echo "下载 FFmpeg ${FFMPEG_VERSION} 源码..."
mkdir -p "$FFMPEG_DIR"
curl -fL -o "/tmp/ffmpeg-${FFMPEG_VERSION}.tar.xz" \
    "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
rm -rf "/tmp/ffmpeg-${FFMPEG_VERSION}"
tar -xf "/tmp/ffmpeg-${FFMPEG_VERSION}.tar.xz" -C /tmp
cp -r "/tmp/ffmpeg-${FFMPEG_VERSION}/." "$FFMPEG_DIR/"
echo "FFmpeg 源码就绪: $FFMPEG_DIR"
