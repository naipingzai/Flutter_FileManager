# ============================================================
# media - 多媒体解码模块
# ============================================================
#
# 提供：
#   - 图片解码（stb_image，单头文件）
#   - 电子书 EPUB（miniz，单文件）
#   - 视频/音频解码（FFmpeg，按需启用）
#   - 音频输出（ALSA/AAudio/AudioQueue/WASAPI）
#   - 压缩包工具（miniz）
#
# 对 Dart FFI 暴露 API 前缀：media_*
# 编译为 STATIC 静态库。
# ============================================================

cmake_minimum_required(VERSION 3.16)
project(media LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ============================================================
# 第三方依赖（miniz + stb_image）
# ============================================================
include(${CMAKE_CURRENT_SOURCE_DIR}/../..//cmake/fetch_thirdparty.cmake)
thirdparty_setup_miniz()
thirdparty_setup_stb_image()

# ============================================================
# Core 源文件
# ============================================================
set(MEDIA_CORE_SOURCES
    core/media_core.cpp
)

# ============================================================
# Platform 源文件（音频输出由各平台实现）
# ============================================================
set(MEDIA_PLATFORM_SOURCES "")

if(WIN32)
    list(APPEND MEDIA_PLATFORM_SOURCES
        platform/windows/src/audio_output_wasapi.cpp
    )
elseif(ANDROID)
    list(APPEND MEDIA_PLATFORM_SOURCES
        platform/android/src/audio_output_aaudio.cpp
    )
elseif(APPLE)
    list(APPEND MEDIA_PLATFORM_SOURCES
        platform/apple/src/audio_output_audio_queue.cpp
    )
else()
    list(APPEND MEDIA_PLATFORM_SOURCES
        platform/linux/src/audio_output_alsa.cpp
    )
endif()

# ============================================================
# 静态库
# ============================================================
add_library(media STATIC
    ${MEDIA_CORE_SOURCES}
    ${MEDIA_PLATFORM_SOURCES}
    ${THIRDPARTY_MINIZ_SRCS}
)

target_include_directories(media
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/core
        ${THIRDPARTY_MINIZ_DIR}
        ${THIRDPARTY_STB_DIR}
)

# 依赖 common 基础层
target_link_libraries(media PUBLIC common)

# ============================================================
# 平台系统库（音频输出等）
# ============================================================
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
    # Linux：音频输出走 ALSA
    target_link_libraries(media PUBLIC asound)
endif()


# ============================================================
# FFmpeg 链接（所有平台使用预编译库，不本地编译源码）
# 从 Flutter_CrossPlatformDependency 仓库 Release 下载当前平台产物。
# ============================================================
set(_ffmpeg_linked FALSE)

# 优先使用外部注入的 FFMPEG_DIR（CI 预置），否则自动下载
set(_ffmpeg_root "")
if(DEFINED FFMPEG_DIR)
    set(_ffmpeg_root "${FFMPEG_DIR}")
elseif(DEFINED ENV{FFMPEG_DIR})
    set(_ffmpeg_root "$ENV{FFMPEG_DIR}")
endif()

if(_ffmpeg_root)
    set(FFMPEG_INCLUDE_DIR "${_ffmpeg_root}/include")
    set(FFMPEG_LIB_DIR     "${_ffmpeg_root}/lib")
    set(FFMPEG_AVAILABLE   TRUE)
    if(ANDROID)
        set(FFMPEG_LIB_DIR "${_ffmpeg_root}/lib/${ANDROID_ABI}")
    endif()
else()
    include(${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/fetch_ffmpeg.cmake)
    fetch_ffmpeg()
endif()

if(FFMPEG_AVAILABLE)
    target_include_directories(media PRIVATE "${FFMPEG_INCLUDE_DIR}")
    if(WIN32)
        target_link_directories(media PRIVATE "${FFMPEG_LIB_DIR}")
        target_link_libraries(media PUBLIC avformat avcodec avutil swscale swresample)
    else()
        target_link_libraries(media PUBLIC
            "${FFMPEG_LIB_DIR}/libavformat.a"
            "${FFMPEG_LIB_DIR}/libavcodec.a"
            "${FFMPEG_LIB_DIR}/libavutil.a"
            "${FFMPEG_LIB_DIR}/libswscale.a"
            "${FFMPEG_LIB_DIR}/libswresample.a"
        )
    endif()
    target_compile_definitions(media PUBLIC HAVE_FFMPEG=1)
    set(_ffmpeg_linked TRUE)
    message(STATUS "[media] FFmpeg enabled")
else()
    message(STATUS "[media] FFmpeg NOT linked - 视频/音频解码桩实现")
endif()
