#!/bin/bash
# ============================================================
# 构建 Android FFmpeg 静态库（4 个 ABI，NDK 交叉编译）
# 产物：native/media/third_party/ffmpeg/android/<abi>/lib + include
# 前置：ANDROID_NDK_HOME 或 ANDROID_NDK_ROOT 或 ANDROID_HOME/ndk/<版本>
# 幂等：对应 ABI 已构建则跳过
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FFMPEG_DIR="$SCRIPT_DIR/../native/media/third_party/ffmpeg"
OUT_ROOT="$FFMPEG_DIR/android"

"$SCRIPT_DIR/fetch_ffmpeg.sh" "$FFMPEG_DIR"

# ---- 定位 NDK ----
NDK="${ANDROID_NDK_HOME:-$ANDROID_NDK_ROOT}"
if [ -z "$NDK" ] && [ -n "$ANDROID_HOME" ]; then
    NDK=$(ls -d "$ANDROID_HOME"/ndk/* 2>/dev/null | sort -V | tail -1)
fi
if [ -z "$NDK" ]; then
    for d in "$HOME"/Android/Sdk/ndk/* /usr/lib/android-sdk/ndk/* /opt/android-sdk/ndk/*; do
        [ -d "$d" ] && NDK="$d" && break
    done
fi
if [ -z "$NDK" ] || [ ! -d "$NDK" ]; then
    echo "ERROR: 未找到 Android NDK（设置 ANDROID_NDK_HOME）"
    exit 1
fi
echo "使用 NDK: $NDK"

TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
API=21

COMMON_CONFIG="
    --target-os=android \
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

build_abi() {
    local ABI="$1" ARCH="$2" CPU="$3" TRIPLE="$4"
    local PREFIX="$OUT_ROOT/$ABI"
    if [ -f "$PREFIX/lib/libavcodec.a" ]; then
        echo "Android FFmpeg [$ABI] 已构建，跳过"
        return
    fi
    local CC="$TOOLCHAIN/bin/${TRIPLE}${API}-clang"
    local CXX="$TOOLCHAIN/bin/${TRIPLE}${API}-clang++"
    local SYSROOT="$TOOLCHAIN/sysroot"
    local BUILD_SRC="$FFMPEG_DIR/../build-src-android-$ABI"
    echo "构建 Android FFmpeg [$ABI] ..."
    # 使用干净源码副本（本地 ffmpeg 目录可能已被 in-tree 构建污染）
    rm -rf "$BUILD_SRC"
    cp -r "$FFMPEG_DIR" "$BUILD_SRC"
    cd "$BUILD_SRC"
    rm -f config.h ffbuild/config.mak
    # shellcheck disable=SC2086
    ./configure \
        --arch="$ARCH" --cpu="$CPU" \
        --cc="$CC" --cxx="$CXX" \
        --sysroot="$SYSROOT" \
        --prefix="$PREFIX" \
        --extra-cflags="-Os -fPIC" \
        $COMMON_CONFIG
    make -j"$(nproc)"
    make install
    cd "$FFMPEG_DIR"
    rm -rf "$BUILD_SRC"
    echo "Android FFmpeg [$ABI] 构建完成 -> $PREFIX"
}

build_abi "arm64-v8a"   "aarch64" "armv8-a" "aarch64-linux-android"
build_abi "armeabi-v7a" "arm"     "armv7-a" "armv7a-linux-androideabi"
build_abi "x86_64"      "x86_64"  "x86-64"  "x86_64-linux-android"
build_abi "x86"         "i686"    "i686"    "i686-linux-android"

echo "Android FFmpeg 全部 ABI 构建完成"
