#!/bin/bash
# ============================================================
# 构建 Linux FFmpeg 静态库（硬性前置：media 库必须依赖）
# 产物：native/media/third_party/ffmpeg/libavcodec/libavcodec.a 等
# 幂等：已构建则跳过
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FFMPEG_DIR="$SCRIPT_DIR/../native/media/third_party/ffmpeg"

"$SCRIPT_DIR/fetch_ffmpeg.sh" "$FFMPEG_DIR"

if [ -f "$FFMPEG_DIR/libavcodec/libavcodec.a" ]; then
    echo "Linux FFmpeg 已构建，跳过"
    exit 0
fi

COMMON_CONFIG="
    --disable-avdevice --disable-avfilter --disable-postproc \
    --disable-network --disable-doc --disable-programs \
    --disable-encoders --disable-muxers --disable-devices \
    --disable-bzlib --disable-lzma --disable-zlib \
    --disable-vaapi --disable-vdpau --disable-xlib --disable-sdl2 \
    --disable-decoder=twinvq,metasound \
    --enable-decoder=h264,hevc,mp3,aac,flac,wavpack,opus,vorbis,pcm_s16le,ac3,eac3 \
    --enable-demuxer=mov,matroska,mp3,flac,wav,ogg,ac3 \
    --enable-protocol=file \
    --enable-avcodec --enable-avformat --enable-avutil --enable-swscale \
    --enable-swresample"

echo "配置 Linux FFmpeg..."
cd "$FFMPEG_DIR"
# shellcheck disable=SC2086
./configure --disable-x86asm --disable-inline-asm $COMMON_CONFIG
echo "编译 Linux FFmpeg..."
make -j"$(nproc)"
echo "Linux FFmpeg 构建完成"
