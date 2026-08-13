# ============================================================
# media - Windows 平台配置
# miniz + stb_image 由 fetch_thirdparty 下载；FFmpeg 链接预编译 MSVC 库（CI 提供 FFMPEG_DIR）
# ============================================================

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/fetch_thirdparty.cmake)

# 1. miniz
thirdparty_setup_miniz()
target_include_directories(media PRIVATE ${THIRDPARTY_MINIZ_DIR})
set(MEDIA_PLATFORM_SOURCES
    ${THIRDPARTY_MINIZ_SRCS}
)

# 2. stb_image
thirdparty_setup_stb_image()
target_include_directories(media PRIVATE ${THIRDPARTY_STB_DIR})

# 3. FFmpeg：预编译 MSVC 静态库。目录需含 include/ 与 lib/*.lib
# 优先取命令行 -DFFMPEG_DIR，其次取环境变量 FFMPEG_DIR
if(NOT DEFINED FFMPEG_DIR AND DEFINED ENV{FFMPEG_DIR})
    set(FFMPEG_DIR "$ENV{FFMPEG_DIR}")
endif()
if(NOT DEFINED FFMPEG_DIR)
    message(FATAL_ERROR "Windows 构建需设置 -DFFMPEG_DIR=<预编译 FFmpeg 目录>（含 include/ 与 lib/av*.lib）")
endif()
set(MEDIA_PLATFORM_LIBS
    ${FFMPEG_DIR}/lib/avformat.lib
    ${FFMPEG_DIR}/lib/avcodec.lib
    ${FFMPEG_DIR}/lib/avutil.lib
    ${FFMPEG_DIR}/lib/swscale.lib
    ${FFMPEG_DIR}/lib/swresample.lib
    ws2_32
    secur32
    bcrypt
    user32
    ole32
)
target_include_directories(media PRIVATE ${FFMPEG_DIR}/include)

target_compile_definitions(media PRIVATE
    MEDIA_PLATFORM_WINDOWS=1
    HAVE_FFMPEG=1
    STB_IMAGE_IMPLEMENTATION=1
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX
)
