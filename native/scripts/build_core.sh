#!/usr/bin/env bash
# ============================================================
# build_core.sh — 只构建 core 静态库（无需联网/无需 FFmpeg）
# 产物：<BUILD_DIR>/libcore.a
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${1:-${NATIVE_DIR}/../build/native-core}"

mkdir -p "$BUILD_DIR"

echo "[core] configuring (code层 + 当前平台 platform 层)..."
cmake -S "${NATIVE_DIR}/core" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release

echo "[core] building..."
cmake --build "$BUILD_DIR" --target core -j"$(nproc)"

echo "[core] done -> ${BUILD_DIR}/libcore.a"
