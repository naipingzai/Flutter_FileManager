# ============================================================
# native - 跨平台原生层统一构建入口（单一 CMake 配置）
# ============================================================
#
# 架构（core + platform 两层）：
#   core/       统一核心层，对接 Dart（FFI 入口 + 各功能跨平台业务逻辑）
#     common/   公共基础（Result、JsonBuilder、Crypto）
#     system/   平台信息（OS、Arch、路径、目录）
#     file/     文件系统操作
#     text/     大文本文件读取
#     media/    媒体解码 + 音频输出接口
#   platform/   跨平台实现（按 OS 目录）
#     posix/    system.cpp   （Linux/macOS/iOS/Android 目录解析）
#     windows/  system.cpp file.cpp audio.cpp
#     linux/    audio.cpp    （ALSA）
#     apple/    audio.cpp    （macOS/iOS AudioQueue）
#     android/  audio.cpp    （AAudio）
#     system.h               （system 平台接口，core 调用、platform 实现）
#
# 调用关系：Dart → core（FFI）→ core 业务 → platform 实现
# 编译为一个静态库 libnative.a（含全部符号），Dart 链接单一产物。
#
# 第三方库一律消费预编译产物（THIRDPARTY_DIR），不下载、不本地编译源码。
# ============================================================

cmake_minimum_required(VERSION 3.16)
project(native LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# 单一静态库输出目录
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

# 原生源码根目录（公共 include 根，统一 #include "core/media/media.h" 等）
set(CPP_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

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

# ============================================================
# 源码清单
# ============================================================
set(NATIVE_SOURCES
    core/src/media.c
)

# platform - 按 OS 选择音频输出实现
if(WIN32)
    list(APPEND NATIVE_SOURCES
        platform/src/windows/audio.c
    )
elseif(ANDROID)
    list(APPEND NATIVE_SOURCES
        platform/src/android/audio.c
    )
elseif(APPLE)
    list(APPEND NATIVE_SOURCES
        platform/src/apple/audio.c
    )
else()
    list(APPEND NATIVE_SOURCES
        platform/src/linux/audio.c
    )
endif()

# ============================================================
# 单一静态库
# ============================================================
add_library(native STATIC ${NATIVE_SOURCES})

# include 路径：
#   core/include      公开头文件（system.h / file.h / media.h / ...）
#   platform/include  平台接口（platform.h）
#   CPP_ROOT          （供 file.cpp 在 Windows 下 include platform/src/windows/file.cpp）
target_include_directories(native PUBLIC
    ${CPP_ROOT}/core/include
    ${CPP_ROOT}/platform/include
    ${CPP_ROOT}
)

# 平台系统库
if(WIN32)
    target_link_libraries(native PUBLIC ole32 shell32)
elseif(ANDROID)
    target_link_libraries(native PUBLIC log aaudio)
elseif(APPLE)
    target_link_libraries(native PUBLIC
        "-framework AudioToolbox"
        "-framework CoreFoundation"
    )
else()
    target_link_libraries(native PUBLIC asound)
endif()

# ============================================================
# 第三方预编译库（FFmpeg + miniz + stb_image）
# 已直接 vendor 到工程 third_party/<platform>/，编译不再下载。
# ============================================================
if(WIN32)
    set(THIRD_PARTY_DIR "${CPP_ROOT}/third_party/windows")
elseif(ANDROID)
    set(THIRD_PARTY_DIR "${CPP_ROOT}/third_party/android")
elseif(APPLE AND CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(THIRD_PARTY_DIR "${CPP_ROOT}/third_party/ios")
elseif(APPLE)
    set(THIRD_PARTY_DIR "${CPP_ROOT}/third_party/macos")
else()
    set(THIRD_PARTY_DIR "${CPP_ROOT}/third_party/linux")
endif()

if(EXISTS "${THIRD_PARTY_DIR}/include" AND EXISTS "${THIRD_PARTY_DIR}/lib")
    target_include_directories(native PRIVATE "${THIRD_PARTY_DIR}/include")
    if(WIN32)
        target_link_directories(native PRIVATE "${THIRD_PARTY_DIR}/lib")
        target_link_libraries(native PUBLIC avformat avcodec avutil swscale swresample miniz)
    else()
        target_link_libraries(native PUBLIC
            "${THIRD_PARTY_DIR}/lib/libavformat.a"
            "${THIRD_PARTY_DIR}/lib/libavcodec.a"
            "${THIRD_PARTY_DIR}/lib/libavutil.a"
            "${THIRD_PARTY_DIR}/lib/libswscale.a"
            "${THIRD_PARTY_DIR}/lib/libswresample.a"
            "${THIRD_PARTY_DIR}/lib/libminiz.a"
        )
    endif()
    message(STATUS "[native] 第三方预编译库: ${THIRD_PARTY_DIR}")
else()
    message(FATAL_ERROR
        "[native] 缺少第三方预编译库目录: ${THIRD_PARTY_DIR}（应为 third_party/<platform>/{include,lib}）")
endif()
