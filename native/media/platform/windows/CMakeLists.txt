# ============================================================
# media - Windows 平台配置
# 集成第三方库：FFmpeg（FetchContent + MSVC 交叉编译）+ miniz + stb_image
# 平台层：WASAPI 音频输出（预留，未实现）
# ============================================================

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/fetch_thirdparty.cmake)

# Windows 尚未打通 FFmpeg 静态库到 MSVC 的链接（需 mingw 工具链生成 .a 后桥接）。
# 默认关闭；media 提供视频/音频桩符号，Dart FFI 仍可安全绑定。
# 如需启用：在 CMake 命令行显式传 -DMEDIA_ENABLE_FFMPEG=ON。
if(NOT DEFINED MEDIA_ENABLE_FFMPEG)
    set(MEDIA_ENABLE_FFMPEG OFF CACHE BOOL "Build FFmpeg-based video/audio decoding" FORCE)
endif()

# ============================================================
# 1. miniz：单文件实现
# ============================================================
thirdparty_setup_miniz()
target_include_directories(media PRIVATE ${THIRDPARTY_MINIZ_DIR})
set(MEDIA_PLATFORM_SOURCES
    ${THIRDPARTY_MINIZ_SRCS}
)

# ============================================================
# 2. stb_image：header-only
# ============================================================
thirdparty_setup_stb_image()
target_include_directories(media PRIVATE ${THIRDPARTY_STB_DIR})

# ============================================================
# 3. FFmpeg：Windows 尚未打通（MEDIA_ENABLE_FFMPEG 默认 OFF），跳过源码构建
# ============================================================
if(MEDIA_ENABLE_FFMPEG)
# 平台层源（暂时空，预留给 WASAPI 输出）
set(MEDIA_PLATFORM_SRC_EXTRA "")

# 注：Windows FFmpeg 构建需要：
#   1. 在 MSYS2 / Git Bash / WSL 中运行 configure（生成 makefile）
#   2. 使用 clang-cl 或 mingw-w64 编译
#   3. 产物为 .a 文件，VS 链接时直接 link .a
#
# 简化策略：使用 mingw-w64 工具链 + LLVM/clang 生成 .a（GCC ABI 兼容）
# 此处仅声明，configure/编译由 build_ffmpeg_windows.sh 在 CI 流程中执行

thirdparty_setup_ffmpeg(FFMPEG_SRC_DIR)
set(FFMPEG_BUILD_DIR "${CMAKE_BINARY_DIR}/_ffmpeg_build_windows")
file(MAKE_DIRECTORY "${FFMPEG_BUILD_DIR}")

# 极简 configure（minGW/Linux ABI；Windows 上需用 mingw 工具链）
set(_FFMPEG_CONFIG_ARGS
    --disable-x86asm --disable-inline-asm
    --disable-avdevice --disable-avfilter --disable-postproc
    --disable-network --disable-doc --disable-programs
    --disable-encoders --disable-muxers --disable-devices
    --disable-bzlib --disable-lzma
    --disable-vaapi --disable-vdpau --disable-xlib --disable-sdl2
    --disable-decoder=twinvq,metasound
    --enable-decoder=h264,hevc,mp3,aac,flac,wavpack,opus,vorbis,pcm_s16le,ac3,eac3
    --enable-demuxer=mov,matroska,mp3,flac,wav,ogg,ac3
    --enable-protocol=file
    --enable-avcodec --enable-avformat --enable-avutil --enable-swscale
    --enable-swresample
)
thirdparty_configure_ffmpeg("${FFMPEG_SRC_DIR}" "${FFMPEG_BUILD_DIR}" "${_FFMPEG_CONFIG_ARGS}")

set(MEDIA_PLATFORM_LIBS
    ${FFMPEG_BUILD_DIR}/lib/libavformat.a
    ${FFMPEG_BUILD_DIR}/lib/libavcodec.a
    ${FFMPEG_BUILD_DIR}/lib/libavutil.a
    ${FFMPEG_BUILD_DIR}/lib/libswscale.a
    ${FFMPEG_BUILD_DIR}/lib/libswresample.a
    ws2_32
    secur32
    bcrypt
    user32
    ole32
)

target_include_directories(media PRIVATE ${FFMPEG_BUILD_DIR}/include)
endif()

target_compile_definitions(media PRIVATE
    MEDIA_PLATFORM_WINDOWS=1
    $<$<BOOL:${MEDIA_ENABLE_FFMPEG}>:HAVE_FFMPEG=1>
    STB_IMAGE_IMPLEMENTATION=1
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX
)
