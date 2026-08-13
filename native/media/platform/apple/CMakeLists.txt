# ============================================================
# media - Apple 平台配置 (macOS / iOS)
# 集成第三方库：FFmpeg（FetchContent + clang 交叉编译）+ miniz + stb_image
# 平台层：AudioQueue 音频输出（预留，未实现）
# ============================================================

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/fetch_thirdparty.cmake)

# iOS/macOS FFmpeg 交叉编译尚未在本工程内验证，默认关闭保证产物可构建。
# 如需启用：在 CMake 命令行显式传 -DMEDIA_ENABLE_FFMPEG=ON。
if(NOT DEFINED MEDIA_ENABLE_FFMPEG)
    set(MEDIA_ENABLE_FFMPEG OFF CACHE BOOL "Build FFmpeg-based video/audio decoding" FORCE)
endif()

# ============================================================
# 1. miniz
# ============================================================
thirdparty_setup_miniz()
target_include_directories(media PRIVATE ${THIRDPARTY_MINIZ_DIR})
set(MEDIA_PLATFORM_SOURCES
    ${THIRDPARTY_MINIZ_SRCS}
)

# ============================================================
# 2. stb_image
# ============================================================
thirdparty_setup_stb_image()
target_include_directories(media PRIVATE ${THIRDPARTY_STB_DIR})

# ============================================================
# 3. FFmpeg（macOS/iOS 通用：clang ABI，可用 MEDIA_ENABLE_FFMPEG 关闭）
# ============================================================
if(MEDIA_ENABLE_FFMPEG)
thirdparty_setup_ffmpeg(FFMPEG_SRC_DIR)
set(FFMPEG_BUILD_DIR "${CMAKE_BINARY_DIR}/_ffmpeg_build_apple")
file(MAKE_DIRECTORY "${FFMPEG_BUILD_DIR}")

# iOS 特殊处理：cross-compile 为 arm64
if(IOS)
    set(_FFMPEG_HOST "--host=aarch64-apple-darwin")
    set(_FFMPEG_EXTRA_CC "--cc=clang --as=clang --ld=clang")
else()
    set(_FFMPEG_HOST "")
    set(_FFMPEG_EXTRA_CC "")
endif()

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
    ${_FFMPEG_HOST}
    ${_FFMPEG_EXTRA_CC}
)
thirdparty_configure_ffmpeg("${FFMPEG_SRC_DIR}" "${FFMPEG_BUILD_DIR}" "${_FFMPEG_CONFIG_ARGS}")

set(MEDIA_PLATFORM_LIBS
    ${FFMPEG_BUILD_DIR}/lib/libavformat.a
    ${FFMPEG_BUILD_DIR}/lib/libavcodec.a
    ${FFMPEG_BUILD_DIR}/lib/libavutil.a
    ${FFMPEG_BUILD_DIR}/lib/libswscale.a
    ${FFMPEG_BUILD_DIR}/lib/libswresample.a
    z
    "-framework AudioToolbox"
    "-framework CoreFoundation"
)

target_include_directories(media PRIVATE ${FFMPEG_BUILD_DIR}/include)
endif()

target_compile_definitions(media PRIVATE
    MEDIA_PLATFORM_APPLE=1
    $<$<BOOL:${MEDIA_ENABLE_FFMPEG}>:HAVE_FFMPEG=1>
    STB_IMAGE_IMPLEMENTATION=1
)
