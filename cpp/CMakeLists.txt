# ============================================================
# native - 跨平台原生层统一构建入口（单一 CMake 配置）
# ============================================================
#
# 架构（按功能分目录，平台代码在 <模块>/platform/ 下）：
#   common/   公共基础层（Result、JsonBuilder、Crypto）
#   system/   平台信息（OS、Arch、路径、目录）       + platform/{posix,windows}.cpp
#   file/     文件系统操作                          + platform/windows.cpp
#   text/     大文本文件读取
#   media/    媒体解码（图片/电子书/视频/音频）        + platform/{alsa,wasapi,aaudio,audio_queue}.cpp
#
# 调用关系：Dart FFI → 模块 ffi → 模块 core → <模块>/platform/ 平台实现
#
# 平台差异只在 <模块>/platform/ 源文件，由本文件按 if(WIN32)/if(APPLE) 选择。
# 第三方库一律消费预编译产物（THIRDPARTY_DIR），不下载、不本地编译源码。
# ============================================================

cmake_minimum_required(VERSION 3.16)
project(native LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# 所有模块静态库统一输出到 ${CMAKE_BINARY_DIR}/cpp，便于集成方与脚本定位
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/cpp")

# 原生源码根目录（所有模块公共 include 根，统一 #include "media/media.h" 等）
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
# common - 公共基础层
# ============================================================
add_library(common STATIC
    common/json/json_builder.c
    common/crypto/crc32.c
    common/crypto/md5.c
    common/crypto/crypto_impl.cpp
)
target_include_directories(common PUBLIC ${CPP_ROOT})
if(MSVC)
    target_compile_options(common PUBLIC /W3 /utf-8)
endif()

# ============================================================
# system - 平台信息
# ============================================================
set(SYSTEM_SOURCES system/system_core.cpp)
if(WIN32)
    list(APPEND SYSTEM_SOURCES system/platform/windows.cpp)
else()
    list(APPEND SYSTEM_SOURCES system/platform/posix.cpp)
endif()
add_library(system STATIC ${SYSTEM_SOURCES})
target_include_directories(system PUBLIC ${CPP_ROOT})
target_link_libraries(system PUBLIC common)
if(WIN32)
    target_link_libraries(system PUBLIC shell32 ole32)
endif()

# ============================================================
# file - 文件系统操作
# ============================================================
set(FILE_SOURCES file/file_core.cpp file/file_ffi.cpp)
if(WIN32)
    list(APPEND FILE_SOURCES file/platform/windows.cpp)
endif()
add_library(file STATIC ${FILE_SOURCES})
target_include_directories(file PUBLIC ${CPP_ROOT})
target_link_libraries(file PUBLIC common system)

# ============================================================
# text - 大文本文件读取
# ============================================================
add_library(text STATIC text/text_core.cpp)
target_include_directories(text PUBLIC ${CPP_ROOT})
target_link_libraries(text PUBLIC common)

# ============================================================
# media - 媒体解码 + 音频输出
# ============================================================
set(MEDIA_SOURCES media/media_core.cpp)
if(WIN32)
    list(APPEND MEDIA_SOURCES media/platform/wasapi.cpp)
elseif(ANDROID)
    list(APPEND MEDIA_SOURCES media/platform/aaudio.cpp)
elseif(APPLE)
    list(APPEND MEDIA_SOURCES media/platform/audio_queue.cpp)
else()
    list(APPEND MEDIA_SOURCES media/platform/alsa.cpp)
endif()
add_library(media STATIC ${MEDIA_SOURCES})
target_include_directories(media PUBLIC ${CPP_ROOT})
target_link_libraries(media PUBLIC common)

# 平台系统库（音频输出等）
if(WIN32)
    target_link_libraries(media PUBLIC ole32)
elseif(ANDROID)
    target_link_libraries(media PUBLIC log aaudio)
elseif(APPLE)
    target_link_libraries(media PUBLIC
        "-framework AudioToolbox"
        "-framework CoreFoundation"
    )
else()
    target_link_libraries(media PUBLIC asound)
endif()

# ---- 第三方预编译库（FFmpeg + miniz + stb_image）----
# 全部由外部提供，通过 THIRDPARTY_DIR（或 FFMPEG_DIR）传入：
#   <dir>/include/  含 libavformat/... 头文件 + miniz.h + stb_image.h
#   <dir>/lib/      含 libav*.a + libminiz.a + libstb_image.a
# 需求清单见仓库根目录 REQUIREMENTS.md
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

set(THIRDPARTY_AVAILABLE FALSE)
if(_tp_root AND EXISTS "${_tp_root}/include" AND EXISTS "${_tp_root}/lib")
    set(THIRDPARTY_AVAILABLE TRUE)
endif()

if(THIRDPARTY_AVAILABLE)
    target_include_directories(media PRIVATE "${_tp_root}/include")
    if(WIN32)
        target_link_directories(media PRIVATE "${_tp_root}/lib")
        target_link_libraries(media PUBLIC avformat avcodec avutil swscale swresample miniz stb_image)
    else()
        target_link_libraries(media PUBLIC
            "${_tp_root}/lib/libavformat.a"
            "${_tp_root}/lib/libavcodec.a"
            "${_tp_root}/lib/libavutil.a"
            "${_tp_root}/lib/libswscale.a"
            "${_tp_root}/lib/libswresample.a"
            "${_tp_root}/lib/libminiz.a"
            "${_tp_root}/lib/libstb_image.a"
        )
    endif()
    target_compile_definitions(media PUBLIC HAVE_FFMPEG=1)
    message(STATUS "[native] 第三方预编译库启用: ${_tp_root}")
else()
    message(WARNING
        "[native] 未找到第三方预编译库（请设置 THIRDPARTY_DIR/FFMPEG_DIR，见 REQUIREMENTS.md）。"
        "本次回退到桩实现（媒体解码不可用）。")
endif()
