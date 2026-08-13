cmake_minimum_required(VERSION 3.16)
project(media LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# FFmpeg：所有平台必须使用（不本地编译源码）。各平台链接预编译 FFmpeg：
#   Linux=系统包(pkg-config)；Windows/Android/Apple=CI 提供 FFMPEG_DIR。
# FFMPEG_DIR 优先取 CMake -D，其次环境变量。

# ============================================================
# base 代码：跨平台功能实现（src/）
# ============================================================
set(MEDIA_BASE_SOURCES
    src/media.cpp
)

# 平台相关源码由各平台 CMake 提供
set(MEDIA_PLATFORM_SOURCES "")

# 静态库（直接集成到 Dart，不编译动态库）
add_library(media STATIC
    ${MEDIA_BASE_SOURCES}
    ${MEDIA_PLATFORM_SOURCES}
)

target_include_directories(media
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/third_party
)

# 引入平台代码（按当前编译平台选择），平台 CMake 负责补充
# MEDIA_PLATFORM_SOURCES / MEDIA_PLATFORM_LIBS / 编译定义
if(WIN32)
    include(${CMAKE_CURRENT_SOURCE_DIR}/platform/windows/CMakeLists.txt)
elseif(ANDROID)
    include(${CMAKE_CURRENT_SOURCE_DIR}/platform/android/CMakeLists.txt)
elseif(APPLE)
    include(${CMAKE_CURRENT_SOURCE_DIR}/platform/apple/CMakeLists.txt)
else()
    # Linux / 其他类 Unix
    include(${CMAKE_CURRENT_SOURCE_DIR}/platform/linux/CMakeLists.txt)
endif()

# 平台补充的源码（在 add_library 之后追加源文件）
target_sources(media PRIVATE ${MEDIA_PLATFORM_SOURCES})

# 平台依赖库由平台 CMake 通过 MEDIA_PLATFORM_LIBS 提供
target_link_libraries(media PUBLIC ${MEDIA_PLATFORM_LIBS})
