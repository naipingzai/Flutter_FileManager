# ============================================================
# media - Linux 平台配置
# miniz + stb_image 由 fetch_thirdparty 下载；FFmpeg 链接系统预编译库（pkg-config）
# ============================================================

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/fetch_thirdparty.cmake)

# 1. miniz：源码编入静态库
thirdparty_setup_miniz()
target_include_directories(media PRIVATE ${THIRDPARTY_MINIZ_DIR})
set(MEDIA_PLATFORM_SOURCES
    ${THIRDPARTY_MINIZ_SRCS}
)

# 2. stb_image：header-only
thirdparty_setup_stb_image()
target_include_directories(media PRIVATE ${THIRDPARTY_STB_DIR})

# 3. FFmpeg：系统预编译库（apt install libavformat-dev libavcodec-dev ...）
find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED IMPORTED_TARGET
    libavformat libavcodec libavutil libswscale libswresample)

set(MEDIA_PLATFORM_LIBS
    PkgConfig::FFMPEG
    stdc++fs
    pthread
    m
    dl
)

# 平台编译定义
target_compile_definitions(media PRIVATE
    MEDIA_PLATFORM_LINUX=1
    HAVE_FFMPEG=1
    STB_IMAGE_IMPLEMENTATION=1
)
