# ============================================================
# media - Android 平台配置
# miniz + stb_image 由 fetch_thirdparty 下载；FFmpeg 链接预编译各 ABI 库（CI 提供 FFMPEG_DIR）
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

# 3. FFmpeg：预编译静态库，目录需含 include/ 与 lib/<abi>/libav*.a
if(DEFINED ANDROID_ABI)
    set(FFMPEG_ABI "${ANDROID_ABI}")
else()
    set(FFMPEG_ABI "arm64-v8a")
endif()
# 优先取命令行 -DFFMPEG_DIR，其次取环境变量 FFMPEG_DIR
if(NOT DEFINED FFMPEG_DIR AND DEFINED ENV{FFMPEG_DIR})
    set(FFMPEG_DIR "$ENV{FFMPEG_DIR}")
endif()
if(NOT DEFINED FFMPEG_DIR)
    message(FATAL_ERROR "Android 构建需设置 -DFFMPEG_DIR=<预编译 FFmpeg 目录>（含 include/ 与 lib/<abi>/libav*.a）")
endif()
set(FFMPEG_ABI_DIR "${FFMPEG_DIR}/lib/${FFMPEG_ABI}")
if(NOT EXISTS "${FFMPEG_ABI_DIR}/libavformat.a")
    message(FATAL_ERROR "未找到预编译 FFmpeg: ${FFMPEG_ABI_DIR}/libavformat.a")
endif()

# FFmpeg 静态库之间互相引用，需用 --start-group/--end-group 解决循环依赖
set(MEDIA_PLATFORM_LIBS
    -Wl,--start-group
    ${FFMPEG_ABI_DIR}/libavformat.a
    ${FFMPEG_ABI_DIR}/libavcodec.a
    ${FFMPEG_ABI_DIR}/libavutil.a
    ${FFMPEG_ABI_DIR}/libswscale.a
    ${FFMPEG_ABI_DIR}/libswresample.a
    -Wl,--end-group
    z
    m
    log
    dl
    aaudio
)
target_include_directories(media PRIVATE ${FFMPEG_DIR}/include)

target_compile_definitions(media PRIVATE
    MEDIA_PLATFORM_ANDROID=1
    HAVE_FFMPEG=1
    STB_IMAGE_IMPLEMENTATION=1
)
