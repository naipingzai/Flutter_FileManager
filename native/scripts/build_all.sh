#!/usr/bin/env bash
# ============================================================
# build_all.sh — 构建 core + media 静态库（含 FFmpeg 下载编译）
# 需要联网下载第三方源码（stb_image / miniz / FFmpeg）。
# 产物：<BUILD_DIR>/libcore.a、<BUILD_DIR>/libmedia.a
#
# Linux 依赖：cmake g++ make tar curl|wget
# media/FFmpeg 额外：libssl-dev zlib1g-dev libasound2-dev
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${1:-${NATIVE_DIR}/../build/native}"

mkdir -p "$BUILD_DIR"

echo "[native] configuring (下载并配置第三方源码，FFmpeg 编译耗时较长)..."
cmake -S "${NATIVE_DIR}" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release

echo "[native] building core + media ..."
cmake --build "$BUILD_DIR" -j"$(nproc)"

echo "[native] done -> ${BUILD_DIR}/libcore.a, ${BUILD_DIR}/libmedia.a"
