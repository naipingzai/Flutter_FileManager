# ============================================================
# media - Linux 平台配置
# ============================================================

# miniz 源码（电子书/压缩包工具，单文件实现）
# 平台层：ALSA 音频输出
set(MEDIA_PLATFORM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/miniz.c
    ${CMAKE_CURRENT_SOURCE_DIR}/platform/linux/src/audio_output_alsa.cpp
)

# FFmpeg 静态库（硬性依赖：必须先运行 build_ffmpeg_linux.sh 生成，
# 在 ffmpeg 源码树内 configure + make）
set(FFMPEG_STATIC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/ffmpeg")

find_package(OpenSSL QUIET)
find_package(ZLIB REQUIRED)
find_package(ALSA REQUIRED)

# FFmpeg 静态库之间互相引用，需用 --start-group/--end-group 解决循环依赖
set(MEDIA_PLATFORM_LIBS
    -Wl,--start-group
    ${FFMPEG_STATIC_DIR}/libavformat/libavformat.a
    ${FFMPEG_STATIC_DIR}/libavcodec/libavcodec.a
    ${FFMPEG_STATIC_DIR}/libavutil/libavutil.a
    ${FFMPEG_STATIC_DIR}/libswscale/libswscale.a
    ${FFMPEG_STATIC_DIR}/libswresample/libswresample.a
    -Wl,--end-group
    ZLIB::ZLIB
    ALSA::ALSA
    m
    pthread
    dl
)

# FFmpeg 头文件
target_include_directories(media PRIVATE ${FFMPEG_STATIC_DIR})

# 启用 FFmpeg 功能
target_compile_definitions(media PRIVATE
    MEDIA_PLATFORM_LINUX=1
    HAVE_FFMPEG=1
)
