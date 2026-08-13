# ============================================================
# media - Linux 平台配置
# 集成第三方库：FFmpeg（FetchContent + 脚本编译）+ miniz（单文件编译）+ stb_image（header-only）
# ============================================================

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/fetch_thirdparty.cmake)

# ============================================================
# 1. miniz：单文件实现，直接编译进 media 静态库
# ============================================================
thirdparty_setup_miniz()
target_include_directories(media PRIVATE ${THIRDPARTY_MINIZ_DIR})
set(MEDIA_PLATFORM_SOURCES
    ${THIRDPARTY_MINIZ_SRCS}
)

# ============================================================
# 2. stb_image：header-only，提供给 media.cpp 使用
# ============================================================
thirdparty_setup_stb_image()
target_include_directories(media PRIVATE ${THIRDPARTY_STB_DIR})

# ============================================================
# 3. FFmpeg：下载源码 + configure + make install（可用 MEDIA_ENABLE_FFMPEG 关闭）
# ============================================================
if(MEDIA_ENABLE_FFMPEG)
thirdparty_setup_ffmpeg(FFMPEG_SRC_DIR)

set(FFMPEG_BUILD_DIR "${CMAKE_BINARY_DIR}/_ffmpeg_build_linux")
file(MAKE_DIRECTORY "${FFMPEG_BUILD_DIR}")

# 极简 configure 参数：仅解码器 + 不依赖外部库
set(_FFMPEG_CONFIG_ARGS
    --disable-x86asm --disable-inline-asm
    --disable-avdevice --disable-avfilter --disable-postproc
    --disable-network --disable-doc --disable-programs
    --disable-encoders --disable-muxers --disable-devices
    --disable-bzlib --disable-lzma --disable-zlib
    --disable-vaapi --disable-vdpau --disable-xlib --disable-sdl2
    --disable-decoder=twinvq,metasound
    --enable-decoder=h264,hevc,mp3,aac,flac,wavpack,opus,vorbis,pcm_s16le,ac3,eac3
    --enable-demuxer=mov,matroska,mp3,flac,wav,ogg,ac3
    --enable-protocol=file
    --enable-avcodec --enable-avformat --enable-avutil --enable-swscale
    --enable-swresample
)

thirdparty_configure_ffmpeg("${FFMPEG_SRC_DIR}" "${FFMPEG_BUILD_DIR}" "${_FFMPEG_CONFIG_ARGS}")

# 链接到 FFmpeg 静态库
find_package(OpenSSL REQUIRED)
find_package(ZLIB REQUIRED)
set(MEDIA_PLATFORM_LIBS
    ${FFMPEG_BUILD_DIR}/lib/libavformat.a
    ${FFMPEG_BUILD_DIR}/lib/libavcodec.a
    ${FFMPEG_BUILD_DIR}/lib/libavutil.a
    ${FFMPEG_BUILD_DIR}/lib/libswscale.a
    ${FFMPEG_BUILD_DIR}/lib/libswresample.a
    OpenSSL::Crypto
    ZLIB::ZLIB
    stdc++fs
    pthread
    m
    dl
)

# FFmpeg 头文件
target_include_directories(media PRIVATE ${FFMPEG_BUILD_DIR}/include)
endif()

# 平台编译定义
target_compile_definitions(media PRIVATE
    MEDIA_PLATFORM_LINUX=1
    $<$<BOOL:${MEDIA_ENABLE_FFMPEG}>:HAVE_FFMPEG=1>
    STB_IMAGE_IMPLEMENTATION=1
)
