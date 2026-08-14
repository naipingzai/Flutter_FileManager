# ============================================================
# native - 跨平台原生层统一构建入口
# ============================================================
#
# 架构：
#   - common/      公共基础层（Result、JsonBuilder、Crypto）
#   - modules/
#     ├── system/   平台信息（OS、Arch、路径、目录）
#     ├── file/     文件系统操作
#     ├── text/     文本文件读取器
#     └── media/    媒体解码（图片/电子书/视频/音频）
#
# 调用关系：
#   Dart FFI → 模块 ffi → 模块 core → 平台实现
#
# 各模块独立编译为静态库，最终链接到 Flutter Native Library。
# 平台差异由各模块的 platform/<os>/ 目录提供实现，
# 由 CMake 通过 if(WIN32)/if(ANDROID)/if(APPLE) 选择。
# ============================================================

cmake_minimum_required(VERSION 3.16)
project(native LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# 全局编译选项
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

if(MSVC)
    add_compile_options(/W3 /utf-8)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS NOMINMAX)
else()
    add_compile_options(-Wall -Wextra -Wno-unused-parameter)
endif()

# 公共基础层（必须先编译，被所有模块依赖）
add_subdirectory(common)

# 功能模块（依赖顺序：system → file → text → media）
add_subdirectory(modules/system)
add_subdirectory(modules/file)
add_subdirectory(modules/text)
add_subdirectory(modules/media)
