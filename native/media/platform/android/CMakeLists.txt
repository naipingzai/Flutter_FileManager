# ============================================================
# media - Android 平台配置
# ============================================================

# miniz 源码（电子书/压缩包工具，单文件实现）
# 平台层：AAudio 音频输出
set(MEDIA_PLATFORM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/miniz.c
    ${CMAKE_CURRENT_SOURCE_DIR}/platform/android/src/audio_output_aaudio.cpp
)

# FFmpeg 静态库（硬性依赖：必须先运行 build_ffmpeg_android.sh，
# 按 ABI 交叉编译到 third_party/ffmpeg/android/<abi>/）
if(DEFINED ANDROID_ABI)
    set(FFMPEG_ABI_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/ffmpeg/android/${ANDROID_ABI}")
else()
    set(FFMPEG_ABI_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/ffmpeg/android")
endif()

# FFmpeg 静态库之间互相引用，需用 --start-group/--end-group 解决循环依赖
set(MEDIA_PLATFORM_LIBS
    -Wl,--start-group
    ${FFMPEG_ABI_DIR}/lib/libavformat.a
    ${FFMPEG_ABI_DIR}/lib/libavcodec.a
    ${FFMPEG_ABI_DIR}/lib/libavutil.a
    ${FFMPEG_ABI_DIR}/lib/libswscale.a
    ${FFMPEG_ABI_DIR}/lib/libswresample.a
    -Wl,--end-group
    z
    m
    log
    dl
    aaudio
)

# FFmpeg 头文件
target_include_directories(media PRIVATE ${FFMPEG_ABI_DIR}/include)

# 启用 FFmpeg 功能
target_compile_definitions(media PRIVATE
    MEDIA_PLATFORM_ANDROID=1
    HAVE_FFMPEG=1
)
