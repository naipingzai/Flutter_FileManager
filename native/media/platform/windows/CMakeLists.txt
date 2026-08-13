# ============================================================
# media - Windows 平台配置
# ============================================================

# miniz 源码（电子书/压缩包工具，单文件实现）
# 平台层：WASAPI 音频输出
set(MEDIA_PLATFORM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/miniz.c
    ${CMAKE_CURRENT_SOURCE_DIR}/platform/windows/src/audio_output_wasapi.cpp
)

# FFmpeg 静态库（硬性依赖：必须先运行 build_ffmpeg_windows.sh，
# 用 MSVC 编译到 third_party/ffmpeg/windows/，产物为 .lib）
set(FFMPEG_STATIC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/ffmpeg/windows")

set(MEDIA_PLATFORM_LIBS
    ${FFMPEG_STATIC_DIR}/lib/libavformat.lib
    ${FFMPEG_STATIC_DIR}/lib/libavcodec.lib
    ${FFMPEG_STATIC_DIR}/lib/libavutil.lib
    ${FFMPEG_STATIC_DIR}/lib/libswscale.lib
    ${FFMPEG_STATIC_DIR}/lib/libswresample.lib
    ws2_32
    secur32
    bcrypt
    user32
    ole32
)

# FFmpeg 头文件
target_include_directories(media PRIVATE ${FFMPEG_STATIC_DIR}/include)

# 启用 FFmpeg 功能
target_compile_definitions(media PRIVATE
    MEDIA_PLATFORM_WINDOWS=1
    HAVE_FFMPEG=1
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX
)
