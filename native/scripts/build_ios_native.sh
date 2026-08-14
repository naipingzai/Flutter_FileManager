#!/usr/bin/env bash
# iOS 原生模块构建（复用统一脚本）
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/build_apple_native.sh" ios "${1:-arm64}"
