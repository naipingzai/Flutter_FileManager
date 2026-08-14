# ============================================================
# common - 跨模块公共基础层
# ============================================================
#
# 提供所有模块共享的：
#   - 公共类型定义（FileType、FileInfo、SearchResult 等）
#   - 错误处理（CommonStatus / ResultCode）
#   - JSON 构建器
#   - 内置加密哈希（MD5/SHA1/SHA256/SHA512/AES256/CRC32）
#
# 编译为 STATIC 静态库，被 modules/* 静态链接。
# ============================================================

cmake_minimum_required(VERSION 3.16)
project(common LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ============================================================
# 源文件
# ============================================================
set(COMMON_SOURCES
    src/json/json_builder.c
    src/crypto/crc32.c
    src/crypto/md5.c
    src/crypto/crypto_impl.cpp
)

# ============================================================
# 静态库
# ============================================================
add_library(common STATIC ${COMMON_SOURCES})

target_include_directories(common
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)

# MSVC 静态库链接修复
if(MSVC)
    target_compile_options(common PUBLIC /W3 /utf-8)
endif()
