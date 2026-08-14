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
project(native LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
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
    # core - 公共基础
    core/src/json/json_builder.c
    core/src/crypto/crc32.c
    core/src/crypto/md5.c
    core/src/crypto/crypto_impl.cpp
    # core - 功能
    core/src/system.cpp
    core/src/file.cpp
    core/src/file_ffi.cpp
    core/src/text.cpp
    core/src/media.cpp
)

# platform - 按 OS 选择实现
if(WIN32)
    list(APPEND NATIVE_SOURCES
        platform/src/windows/system.cpp
        platform/src/windows/file.cpp
        platform/src/windows/audio.cpp
    )
elseif(ANDROID)
    list(APPEND NATIVE_SOURCES
        platform/src/posix/system.cpp
        platform/src/android/audio.cpp
    )
elseif(APPLE)
    list(APPEND NATIVE_SOURCES
        platform/src/posix/system.cpp
        platform/src/apple/audio.cpp
    )
else()
    list(APPEND NATIVE_SOURCES
        platform/src/posix/system.cpp
        platform/src/linux/audio.cpp
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
# 通过 THIRDPARTY_DIR（或 FFMPEG_DIR）传入，见 REQUIREMENTS.md
# ============================================================
set(_tp_root "")
if(DEFINED THIRDPARTY_DIR)
    set(_tp_root "${THIRDPARTY_DIR}")
elseif(DEFINED ENV{THIRDPARTY_DIR})
    set(_tp_root "$ENV{THIRDPARTY_DIR}")
elseif(DEFINED FFMPEG_DIR)
    set(_tp_root "${FFMPEG_DIR}")
elseif(DEFINED ENV{FFMPEG_DIR})
    set(_tp_root "$ENV{FFMPEG_DIR}")
endif()

if(_tp_root AND EXISTS "${_tp_root}/include" AND EXISTS "${_tp_root}/lib")
    target_include_directories(native PRIVATE "${_tp_root}/include")
    if(WIN32)
        target_link_directories(native PRIVATE "${_tp_root}/lib")
        target_link_libraries(native PUBLIC avformat avcodec avutil swscale swresample miniz stb_image)
    else()
        target_link_libraries(native PUBLIC
            "${_tp_root}/lib/libavformat.a"
            "${_tp_root}/lib/libavcodec.a"
            "${_tp_root}/lib/libavutil.a"
            "${_tp_root}/lib/libswscale.a"
            "${_tp_root}/lib/libswresample.a"
            "${_tp_root}/lib/libminiz.a"
            "${_tp_root}/lib/libstb_image.a"
        )
    endif()
    target_compile_definitions(native PUBLIC HAVE_FFMPEG=1)
    message(STATUS "[native] 第三方预编译库启用: ${_tp_root}")
else()
    message(WARNING
        "[native] 未找到第三方预编译库（请设置 THIRDPARTY_DIR/FFMPEG_DIR，见 REQUIREMENTS.md）。"
        "本次回退到桩实现（媒体解码不可用）。")
endif()
