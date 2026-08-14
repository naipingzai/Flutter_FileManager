# ============================================================
# system - 平台信息模块
# ============================================================
#
# 提供 OS / Arch / Path / 标准目录的统一访问。
# Dart 不直接调用 Platform.isXxx，所有平台信息都通过 system_info() 获取。
#
# 编译为 STATIC 静态库。
# ============================================================

cmake_minimum_required(VERSION 3.16)
project(system LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ============================================================
# Core 源文件（跨平台统一）
# ============================================================
set(SYSTEM_CORE_SOURCES
    core/system_info_core.cpp
)

# ============================================================
# Platform 源文件（由 CMake 根据当前编译平台选择）
# ============================================================
set(SYSTEM_PLATFORM_SOURCES "")

if(WIN32)
    list(APPEND SYSTEM_PLATFORM_SOURCES
        platform/windows/src/platform_system_windows.cpp
    )
elseif(ANDROID OR APPLE)
    # POSIX 平台共用一个实现（Linux/macOS/iOS/Android）
    list(APPEND SYSTEM_PLATFORM_SOURCES
        platform/linux/src/platform_system_posix.cpp
    )
else()
    # Linux / 其他类 Unix
    list(APPEND SYSTEM_PLATFORM_SOURCES
        platform/linux/src/platform_system_posix.cpp
    )
endif()

# ============================================================
# 静态库
# ============================================================
add_library(system STATIC
    ${SYSTEM_CORE_SOURCES}
    ${SYSTEM_PLATFORM_SOURCES}
)

target_include_directories(system
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/core
)

# 依赖 common 基础层
target_link_libraries(system PUBLIC common)

# 平台链接库
if(WIN32)
    target_link_libraries(system PUBLIC shell32 ole32)
endif()
