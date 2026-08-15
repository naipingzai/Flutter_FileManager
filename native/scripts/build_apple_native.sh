#!/usr/bin/env bash
# ============================================================
# build_apple_native.sh - Apple (iOS/macOS) 原生模块统一构建脚本
#
# 把 cpp/core + cpp/platform 合并为一个 libflutter_native.a，
# 供 Xcode 通过 -force_load 静态链接，使 Dart 的
# DynamicLibrary.process() 能查到符号（静态链接进主二进制）。
#
# 用法：build_apple_native.sh <ios|macos>
#
# 依赖：
#   - 第三方预编译库已 vendor 在工程 third_party/<platform>/{include,lib}，无需下载
#   - 输出到 <repo>/build/native/<platform>/libflutter_native.a
# ============================================================
set -euo pipefail

PLATFORM="${1:?用法: build_apple_native.sh <ios|macos>}"
if [[ "$PLATFORM" != "ios" && "$PLATFORM" != "macos" ]]; then
    echo "未知平台: $PLATFORM（仅支持 ios|macos）" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CPP_DIR="${REPO_ROOT}/native"
BUILD_DIR="${REPO_ROOT}/build/native/${PLATFORM}"
ARCH="${2:-arm64}"
TP_DIR="${REPO_ROOT}/native/third_party/${PLATFORM}"
OUT_A="${BUILD_DIR}/libflutter_native.a"

# 若产物已存在且非空则直接复用（Xcode 脚本阶段二次运行时避免重复构建/清空）
if [[ -s "${OUT_A}" ]]; then
    echo "[native] 产物已存在，跳过构建: ${OUT_A}"
    exit 0
fi

CMAKE_ARGS=(
    -S "${CPP_DIR}"
    -B "${BUILD_DIR}"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_OSX_ARCHITECTURES="${ARCH}"
)

if [[ "$PLATFORM" == "ios" ]]; then
    # iOS 交叉编译必须用 Xcode 生成器 + iphoneos SDK（CMAKE_SYSTEM_NAME=iOS 不能配 Makefiles）
    CMAKE_ARGS+=(
        -DCMAKE_SYSTEM_NAME=iOS
        -DCMAKE_OSX_SYSROOT=iphoneos
        -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0
        -G Xcode
    )
fi

# 增量构建：若已存在 CMake 缓存则复用（避免 Xcode 脚本阶段二次运行时清掉已产出的库）
if [[ ! -f "${BUILD_DIR}/CMakeCache.txt" ]]; then
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
    echo "[native] CMake 配置 ($PLATFORM/$ARCH)..."
    cmake "${CMAKE_ARGS[@]}"
else
    echo "[native] 复用已有 CMake 缓存 ($PLATFORM/$ARCH)"
fi

echo "[native] 编译模块..."
cmake --build "${BUILD_DIR}" --config Release --parallel

# ============================================================
# 合并所有模块 .a + 第三方 .a 为单一 libflutter_native.a
# ============================================================
rm -f "${OUT_A}"

# 模块静态库（Xcode 生成器可能放到带 config 的子目录，递归查找）
MODULE_LIBS=""
MODULE_LIBS=$(find "${BUILD_DIR}" -name "libnative.a" 2>/dev/null | head -1)

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
