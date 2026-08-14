# ============================================================
# text - 大文本文件读取模块
# ============================================================
#
# 提供：
#   - 大文本文件高效读取（行索引 / 分块读取）
#   - 句柄式 API（create/destroy/open/close/read/read_line）
#
# 对 Dart FFI 暴露 API 前缀：text_*
# 编译为 STATIC 静态库。
# ============================================================

cmake_minimum_required(VERSION 3.16)
project(text LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ============================================================
# Core 源文件
# ============================================================
set(TEXT_CORE_SOURCES
    core/text_ops_core.cpp
)

# ============================================================
# 静态库
# ============================================================
add_library(text STATIC ${TEXT_CORE_SOURCES})

target_include_directories(text
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/core
)

# 依赖 common 基础层
target_link_libraries(text PUBLIC common)
