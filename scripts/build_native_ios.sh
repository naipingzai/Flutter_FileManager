#!/bin/bash
# ============================================================
# 构建 iOS native 静态库（core + media，arm64 iphoneos）
# 前置：先运行 build_ffmpeg_ios.sh
# 产物：build/native/ios/libcore.a + libmedia.a
# 由 Xcode 通过 ios/Flutter/*.xcconfig 的 OTHER_LDFLAGS 链接
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$PROJECT_DIR/build/native/ios"

mkdir -p "$BUILD_DIR"

cmake -S "$PROJECT_DIR/native" -B "$BUILD_DIR" \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_BUILD_TYPE=Release

cmake --build "$BUILD_DIR" --config Release --target core media -j"$(sysctl -n hw.ncpu)"

echo "iOS native 静态库构建完成:"
ls -la "$BUILD_DIR/Release/"*.a
