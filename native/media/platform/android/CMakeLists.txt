# ============================================================
# media - Android 平台配置
# 集成第三方库：FFmpeg（FetchContent + NDK 交叉编译，按 ABI 输出）+ miniz + stb_image
# 平台层：AAudio 音频输出（预留，未实现）
# ============================================================

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/fetch_thirdparty.cmake)

# Android FFmpeg 交叉编译（toolchain prefix）尚未验证，默认关闭保证 APK 可构建。
# 如需启用：在 gradle externalNativeBuild 传入 -DMEDIA_ENABLE_FFMPEG=ON。
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
# 3. FFmpeg：按 ABI 交叉编译（可用 MEDIA_ENABLE_FFMPEG 关闭）
# ============================================================
if(MEDIA_ENABLE_FFMPEG)
thirdparty_setup_ffmpeg(FFMPEG_SRC_DIR)

# 根据 NDK ABI 决定 host triplet 和 build dir
if(DEFINED ANDROID_ABI)
    set(FFMPEG_ABI "${ANDROID_ABI}")
else()
    # 默认 arm64
    set(FFMPEG_ABI "arm64-v8a")
endif()

set(FFMPEG_BUILD_DIR "${CMAKE_BINARY_DIR}/_ffmpeg_build_android_${FFMPEG_ABI}")
file(MAKE_DIRECTORY "${FFMPEG_BUILD_DIR}")

# Android 各 ABI 对应 FFmpeg host triplet
if(FFMPEG_ABI STREQUAL "arm64-v8a")
    set(_FFMPEG_HOST "--host=aarch64-linux-android")
elseif(FFMPEG_ABI STREQUAL "armeabi-v7a")
    set(_FFMPEG_HOST "--host=arm-linux-androideabi")
elseif(FFMPEG_ABI STREQUAL "x86_64")
    set(_FFMPEG_HOST "--host=x86_64-linux-android")
elseif(FFMPEG_ABI STREQUAL "x86")
    set(_FFMPEG_HOST "--host=i686-linux-android")
else()
    message(FATAL_ERROR "[media] 不支持的 Android ABI: ${FFMPEG_ABI}")
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
    --cc=${ANDROID_TOOLCHAIN_PREFIX}clang
    ${_FFMPEG_HOST}
)
thirdparty_configure_ffmpeg("${FFMPEG_SRC_DIR}" "${FFMPEG_BUILD_DIR}" "${_FFMPEG_CONFIG_ARGS}")

# FFmpeg 静态库之间互相引用，需用 --start-group/--end-group 解决循环依赖
set(MEDIA_PLATFORM_LIBS
    -Wl,--start-group
    ${FFMPEG_BUILD_DIR}/lib/libavformat.a
    ${FFMPEG_BUILD_DIR}/lib/libavcodec.a
    ${FFMPEG_BUILD_DIR}/lib/libavutil.a
    ${FFMPEG_BUILD_DIR}/lib/libswscale.a
    ${FFMPEG_BUILD_DIR}/lib/libswresample.a
    -Wl,--end-group
    z
    m
    log
    dl
    aaudio
)

target_include_directories(media PRIVATE ${FFMPEG_BUILD_DIR}/include)
endif()

target_compile_definitions(media PRIVATE
    MEDIA_PLATFORM_ANDROID=1
    $<$<BOOL:${MEDIA_ENABLE_FFMPEG}>:HAVE_FFMPEG=1>
    STB_IMAGE_IMPLEMENTATION=1
)
