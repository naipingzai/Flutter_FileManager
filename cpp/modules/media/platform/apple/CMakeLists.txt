# ============================================================
# media - Apple 平台配置 (macOS / iOS)
# miniz + stb_image 由 fetch_thirdparty 下载；FFmpeg 链接预编译库（CI 提供 FFMPEG_DIR）
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

# 3. FFmpeg：预编译静态库。目录需含 include/ 与 lib/*.a
# 优先取命令行 -DFFMPEG_DIR，其次取环境变量 FFMPEG_DIR
if(NOT DEFINED FFMPEG_DIR AND DEFINED ENV{FFMPEG_DIR})
    set(FFMPEG_DIR "$ENV{FFMPEG_DIR}")
endif()
if(NOT DEFINED FFMPEG_DIR)
    message(FATAL_ERROR "Apple 构建需设置 -DFFMPEG_DIR=<预编译 FFmpeg 目录>（含 include/ 与 lib/libav*.a）")
endif()
set(MEDIA_PLATFORM_LIBS
    ${FFMPEG_DIR}/lib/libavformat.a
    ${FFMPEG_DIR}/lib/libavcodec.a
    ${FFMPEG_DIR}/lib/libavutil.a
    ${FFMPEG_DIR}/lib/libswscale.a
    ${FFMPEG_DIR}/lib/libswresample.a
    z
    "-framework AudioToolbox"
    "-framework CoreFoundation"
)
target_include_directories(media PRIVATE ${FFMPEG_DIR}/include)

target_compile_definitions(media PRIVATE
    MEDIA_PLATFORM_APPLE=1
    HAVE_FFMPEG=1
    STB_IMAGE_IMPLEMENTATION=1
)
