# ============================================================
# media - Apple 平台配置 (macOS / iOS)
# ============================================================

# miniz 源码（电子书/压缩包工具，单文件实现）
# 平台层：AudioQueue 音频输出
set(MEDIA_PLATFORM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/miniz.c
    ${CMAKE_CURRENT_SOURCE_DIR}/platform/apple/src/audio_output_audio_queue.cpp
)

# FFmpeg 静态库（硬性依赖：必须先运行 build_ffmpeg_ios.sh，
# 用 clang 交叉编译到 third_party/ffmpeg/ios/）
set(FFMPEG_STATIC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/ffmpeg/ios")

set(MEDIA_PLATFORM_LIBS
    ${FFMPEG_STATIC_DIR}/lib/libavformat.a
    ${FFMPEG_STATIC_DIR}/lib/libavcodec.a
    ${FFMPEG_STATIC_DIR}/lib/libavutil.a
    ${FFMPEG_STATIC_DIR}/lib/libswscale.a
    ${FFMPEG_STATIC_DIR}/lib/libswresample.a
    z
    "-framework AudioToolbox"
    "-framework CoreFoundation"
)

# FFmpeg 头文件
target_include_directories(media PRIVATE ${FFMPEG_STATIC_DIR}/include)

# 启用 FFmpeg 功能
target_compile_definitions(media PRIVATE
    MEDIA_PLATFORM_APPLE=1
    HAVE_FFMPEG=1
)
