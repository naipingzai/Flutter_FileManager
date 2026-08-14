# ============================================================
# file - 文件系统模块
# ============================================================
#
# 提供：
#   - 目录/文件列表、文件信息
#   - 搜索、去重、空文件、最近文件
#   - 文件操作（创建/删除/重命名/复制/移动/链接）
#   - 哈希计算（MD5/SHA1/SHA256/SHA512/CRC32）
#   - 加密/解密（AES-256-CBC）
#   - 文本/CSV/二进制文件 I/O
#
# 对 Dart FFI 暴露 API 前缀：file_*
# 编译为 STATIC 静态库。
# ============================================================

cmake_minimum_required(VERSION 3.16)
project(file LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ============================================================
# Core 源文件
# ============================================================
set(FILE_CORE_SOURCES
    core/file_ops_core.cpp
    ffi/file_ops_ffi.cpp
)

# ============================================================
# Platform 源文件（POSIX 平台不需要额外；Windows 需要 POSIX 兼容层）
# ============================================================
set(FILE_PLATFORM_SOURCES "")

if(WIN32)
    list(APPEND FILE_PLATFORM_SOURCES
        platform/windows/src/file_ops_win.cpp
    )
endif()

# ============================================================
# 静态库
# ============================================================
add_library(file STATIC
    ${FILE_CORE_SOURCES}
    ${FILE_PLATFORM_SOURCES}
)

target_include_directories(file
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/core
)

# 依赖 common 基础层与 system 模块（标准目录由 system 提供）
target_link_libraries(file PUBLIC common system)
