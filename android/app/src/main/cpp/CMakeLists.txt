# Android FFI 载体：将 modules 静态库打包为 libfileops.so
# Dart 端通过 DynamicLibrary.open('libfileops.so') 加载
cmake_minimum_required(VERSION 3.18)
project(fileops LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# 引入原生层（单一 CMake 配置，产出 libnative.a）
set(NATIVE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native")
add_subdirectory("${NATIVE_ROOT}" "${CMAKE_BINARY_DIR}/native")

# 共享库载体（无实际源码，仅链接静态库）
add_library(fileops SHARED
    empty.cpp
)

# 强制包含全部符号（FFI 通过符号查找调用）
target_link_libraries(fileops PRIVATE
    -Wl,--whole-archive
    native
    -Wl,--no-whole-archive
    z
    log
    aaudio
)

# 解决 FFmpeg 静态库在共享库(.so)中的符号绑定：
# -Bsymbolic 让动态符号优先绑定本地定义，规避对全局数据符号的 ADR 重定位报错。
target_link_options(fileops PRIVATE -Wl,-Bsymbolic)