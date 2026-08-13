#!/bin/sh
# ============================================================
# build_ios_native.sh — 在 Xcode 构建阶段编译 core/media 静态库(iOS arm64)
# FFmpeg 使用预编译库，目录：<repo>/build/native/ios/ffmpeg
#   （含 include/ 与 lib/libav*.a，由 CI 脚本下载）
# 产物：<repo>/build/native/ios/libcore.a、libmedia.a
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${ROOT}/build/native/ios"
FFMPEG_DIR="${BUILD_DIR}/ffmpeg"

if [ ! -d "${FFMPEG_DIR}/include" ] || [ ! -f "${FFMPEG_DIR}/lib/libavformat.a" ]; then
  echo "error: 未找到预编译 iOS FFmpeg（${FFMPEG_DIR}）。请先下载并放置 include/ 与 lib/libav*.a。" >&2
  exit 1
fi

echo "[ios-native] configuring core+media for iOS (arm64)..."
cmake -S "${ROOT}/native" -B "$BUILD_DIR" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DFFMPEG_DIR="${FFMPEG_DIR}" \
    -DCMAKE_BUILD_TYPE=Release

echo "[ios-native] building core + media ..."
cmake --build "$BUILD_DIR" --target core media -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

echo "[ios-native] done: ${BUILD_DIR}/libcore.a, ${BUILD_DIR}/libmedia.a"
