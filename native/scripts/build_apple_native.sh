#!/usr/bin/env bash
# ============================================================
# build_apple_native.sh - Apple (iOS/macOS) 原生模块统一构建脚本
#
# 把 C++ 模块（common/system/file/text/media）+ FFmpeg 静态库
# 合并为一个 libflutter_native.a，供 Xcode 通过 -force_load 静态链接，
# 使 Dart 的 DynamicLibrary.process() 能查到符号（遵循 skill：静态链接进主二进制）。
#
# 用法：
#   build_apple_native.sh <ios|macos>
#
# 依赖：
#   - 第三方预编译库（FFmpeg + miniz + stb_image），通过 THIRDPARTY_DIR 提供：
#     <dir>/include + <dir>/lib/lib*.a（不下载、不本地编译源码，见 REQUIREMENTS.md）
#   - 输出到 <repo>/build/native/<platform>/libflutter_native.a
# ============================================================
set -euo pipefail

PLATFORM="${1:?用法: build_apple_native.sh <ios|macos>}"
if [[ "$PLATFORM" != "ios" && "$PLATFORM" != "macos" ]]; then
    echo "未知平台: $PLATFORM（仅支持 ios|macos）" >&2
    exit 1
fi

# 第三方预编译库必须由外部提供
TP_DIR="${THIRDPARTY_DIR:-${FFMPEG_DIR:-}}"
if [[ -z "${TP_DIR}" ]]; then
    echo "[native] 错误：未设置 THIRDPARTY_DIR（指向预编译 FFmpeg+miniz+stb_image，见 REQUIREMENTS.md）" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CPP_DIR="${REPO_ROOT}/cpp"
BUILD_DIR="${REPO_ROOT}/build/native/${PLATFORM}"
ARCH="${2:-arm64}"

# 每次全量构建模块，避免 CMake 缓存跨平台残留
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

CMAKE_ARGS=(
    -S "${CPP_DIR}"
    -B "${BUILD_DIR}"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_OSX_ARCHITECTURES="${ARCH}"
    -DTHIRDPARTY_DIR="${TP_DIR}"
)

if [[ "$PLATFORM" == "ios" ]]; then
    CMAKE_ARGS+=(-DCMAKE_SYSTEM_NAME=iOS)
fi

echo "[native] CMake 配置 ($PLATFORM/$ARCH)..."
cmake "${CMAKE_ARGS[@]}"

echo "[native] 编译模块..."
cmake --build "${BUILD_DIR}" --config Release --parallel

# ============================================================
# 合并所有模块 .a + 第三方 .a 为单一 libflutter_native.a
# ============================================================
OUT_A="${BUILD_DIR}/libflutter_native.a"
rm -f "${OUT_A}"

# 模块静态库统一输出到 ${BUILD_DIR}/lib/（见 cpp/CMakeLists.txt，单一 libnative.a）
MODULE_LIBS=""
if [[ -f "${BUILD_DIR}/lib/libnative.a" ]]; then
    MODULE_LIBS="${BUILD_DIR}/lib/libnative.a"
fi

# 第三方预编译静态库：${TP_DIR}/lib
TP_LIBS=""
if [[ -d "${TP_DIR}/lib" ]]; then
    TP_LIBS=$(ls "${TP_DIR}"/lib/lib*.a 2>/dev/null || true)
fi

ALL_LIBS="${MODULE_LIBS} ${TP_LIBS}"
if [[ -z "${MODULE_LIBS}" ]]; then
    echo "[native] 未找到任何模块静态库，合并失败" >&2
    exit 1
fi

echo "[native] 合并静态库:"
for l in ${ALL_LIBS}; do echo "  - ${l}"; done

# 用 libtool -static 合并（macOS 的 ar 不支持 GNU MRI -M 脚本）
if command -v libtool >/dev/null 2>&1; then
    libtool -static -o "${OUT_A}" ${ALL_LIBS}
else
    echo "[native] 未找到 libtool，改用 解包+重打包 合并" >&2
    MERGE_DIR="${BUILD_DIR}/_merge_tmp"
    rm -rf "${MERGE_DIR}"; mkdir -p "${MERGE_DIR}"
    n=0
    for l in ${ALL_LIBS}; do
        d="${MERGE_DIR}/lib_${n}"; mkdir -p "${d}"
        (cd "${d}" && ar -x "${l}")
        n=$((n+1))
    done
    # shellcheck disable=SC2035
    (cd "${MERGE_DIR}" && find . -name '*.o' -exec ar -rcs "${OUT_A}" {} +)
    rm -rf "${MERGE_DIR}"
fi
ranlib "${OUT_A}"

echo "[native] 完成: ${OUT_A}"
ls -lh "${OUT_A}"
