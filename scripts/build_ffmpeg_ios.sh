#!/bin/bash
# ============================================================
# 构建 iOS FFmpeg 静态库（clang 交叉编译，arm64 iphoneos）
# 产物：native/media/third_party/ffmpeg/ios/lib + include
# 运行环境：macOS（含 Xcode）
# 幂等：已构建则跳过
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FFMPEG_DIR="$SCRIPT_DIR/../native/media/third_party/ffmpeg"
PREFIX="$FFMPEG_DIR/ios"

"$SCRIPT_DIR/fetch_ffmpeg.sh" "$FFMPEG_DIR"

if [ -f "$PREFIX/lib/libavcodec.a" ]; then
    echo "iOS FFmpeg 已构建，跳过"
    exit 0
fi

SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
MIN_IOS="12.0"

COMMON_CONFIG="
    --target-os=darwin \
    --enable-cross-compile \
    --disable-asm --disable-inline-asm \
    --disable-avdevice --disable-avfilter --disable-postproc \
    --disable-network --disable-doc --disable-programs \
    --disable-encoders --disable-muxers --disable-devices \
    --disable-bzlib --disable-lzma --disable-zlib \
    --disable-decoder=twinvq,metasound \
    --enable-decoder=h264,hevc,mp3,aac,flac,wavpack,opus,vorbis,pcm_s16le,ac3,eac3 \
    --enable-demuxer=mov,matroska,mp3,flac,wav,ogg,ac3 \
    --enable-protocol=file \
    --enable-avcodec --enable-avformat --enable-avutil --enable-swscale \
    --enable-swresample"

BUILD_SRC="$FFMPEG_DIR/../build-src-ios"
echo "构建 iOS FFmpeg ..."
# 使用干净源码副本（ffmpeg 目录可能已被其他平台构建污染）
rm -rf "$BUILD_SRC"
cp -r "$FFMPEG_DIR" "$BUILD_SRC"
cd "$BUILD_SRC"
rm -f config.h ffbuild/config.mak
# shellcheck disable=SC2086
./configure \
    --arch=aarch64 --cpu=armv8-a \
    --cc=clang --cxx=clang++ \
    --sysroot="$SDK_PATH" \
    --prefix="$PREFIX" \
    --extra-cflags="-arch arm64 -miphoneos-version-min=${MIN_IOS} -fPIC -Os" \
    --extra-ldflags="-arch arm64 -miphoneos-version-min=${MIN_IOS}" \
    $COMMON_CONFIG
make -j"$(sysctl -n hw.ncpu)"
make install
cd "$FFMPEG_DIR"
rm -rf "$BUILD_SRC"
echo "iOS FFmpeg 构建完成 -> $PREFIX"
