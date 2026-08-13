# Android FFI 载体：将 core/media 静态库打包为 libfileops.so
# Dart 端通过 DynamicLibrary.open('libfileops.so') 加载
cmake_minimum_required(VERSION 3.18)
project(fileops LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# 引入代码层 + 平台层（native/core 与 native/media 各自按平台 CMake 编译）
set(NATIVE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native")
add_subdirectory("${NATIVE_ROOT}/core" "${CMAKE_BINARY_DIR}/native/core")
add_subdirectory("${NATIVE_ROOT}/media" "${CMAKE_BINARY_DIR}/native/media")

# 共享库载体（无实际源码，仅链接静态库）
add_library(fileops SHARED
    empty.cpp
)

# 强制包含全部符号（FFI 通过符号查找调用）
target_link_libraries(fileops PRIVATE
    -Wl,--whole-archive
    core
    media
    -Wl,--no-whole-archive
)
