#!/bin/bash
# ============================================================
# 构建 Windows FFmpeg 静态库（MSVC 编译）
# 产物：native/media/third_party/ffmpeg/windows/lib + include（.lib 静态库）
# 运行环境：windows-latest（含 Visual Studio，通过 vcvars64 初始化）
# 幂等：已构建则跳过
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FFMPEG_DIR="$SCRIPT_DIR/../native/media/third_party/ffmpeg"
PREFIX="$FFMPEG_DIR/windows"

"$SCRIPT_DIR/fetch_ffmpeg.sh" "$FFMPEG_DIR"

if [ -f "$PREFIX/lib/libavcodec.lib" ]; then
    echo "Windows FFmpeg 已构建，跳过"
    exit 0
fi

VSWHERE="C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
VSPATH=$("$VSWHERE" -latest -property installationPath)
if [ -z "$VSPATH" ]; then
    echo "ERROR: 未找到 Visual Studio"
    exit 1
fi
VCVARS="$VSPATH/VC/Auxiliary/Build/vcvars64.bat"

COMMON_CONFIG="
    --toolchain=msvc \
    --enable-static --disable-shared \
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

BUILD_SRC="$FFMPEG_DIR/../build-src-windows"
echo "构建 Windows FFmpeg ..."
# 使用干净源码副本（ffmpeg 目录可能已被其他平台构建污染）
rm -rf "$BUILD_SRC"
cp -r "$FFMPEG_DIR" "$BUILD_SRC"
cd "$BUILD_SRC"
rm -f config.h ffbuild/config.mak

# 在 vcvars64 环境中执行 configure + nmake（MSYS 路径转 Windows 路径）
WIN_BUILD_SRC=$(cygpath -w "$BUILD_SRC")
WIN_PREFIX=$(cygpath -w "$PREFIX")
# shellcheck disable=SC2086
cmd //c "call \"$VCVARS\" && cd /d $WIN_BUILD_SRC && configure --toolchain=msvc --disable-x86asm --prefix=$WIN_PREFIX $COMMON_CONFIG && nmake && nmake install"
cd "$FFMPEG_DIR"
rm -rf "$BUILD_SRC"
echo "Windows FFmpeg 构建完成 -> $PREFIX"
