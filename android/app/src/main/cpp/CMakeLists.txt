# Android FFI 载体：将 modules 静态库打包为 libfileops.so
# Dart 端通过 DynamicLibrary.open('libfileops.so') 加载
cmake_minimum_required(VERSION 3.18)
project(fileops LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# 引入 common 基础层 + 各功能模块（统一 modules/ 结构）
set(NATIVE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../cpp")
add_subdirectory("${NATIVE_ROOT}/common"  "${CMAKE_BINARY_DIR}/native/common")
add_subdirectory("${NATIVE_ROOT}/modules/system" "${CMAKE_BINARY_DIR}/native/system")
add_subdirectory("${NATIVE_ROOT}/modules/file"   "${CMAKE_BINARY_DIR}/native/file")
add_subdirectory("${NATIVE_ROOT}/modules/text"   "${CMAKE_BINARY_DIR}/native/text")
add_subdirectory("${NATIVE_ROOT}/modules/media"  "${CMAKE_BINARY_DIR}/native/media")

# 共享库载体（无实际源码，仅链接静态库）
add_library(fileops SHARED
    empty.cpp
)

# 强制包含全部符号（FFI 通过符号查找调用）
target_link_libraries(fileops PRIVATE
    -Wl,--whole-archive
    common
    system
    file
    text
    media
    -Wl,--no-whole-archive
)