cmake_minimum_required(VERSION 3.13)
project(core LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ============================================================
# base 代码：跨平台功能实现（src/）
# 整合了原 file_ops + text_ops 两大功能模块
# ============================================================
set(CORE_BASE_SOURCES
    src/file_ops.cpp
    src/file_ops_json.cpp
    src/text_ops.cpp
)

# 平台相关源码由各平台 CMake 提供
set(CORE_PLATFORM_SOURCES "")

# 静态库（直接集成到 Dart，不编译动态库）
add_library(core STATIC
    ${CORE_BASE_SOURCES}
    ${CORE_PLATFORM_SOURCES}
)

target_include_directories(core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# 引入平台代码（按当前编译平台选择），平台 CMake 负责补充
# CORE_PLATFORM_SOURCES / CORE_PLATFORM_LIBS / 编译定义
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
target_sources(core PRIVATE ${CORE_PLATFORM_SOURCES})

# 依赖的系统库由平台 CMake 通过 CORE_PLATFORM_LIBS 提供
target_link_libraries(core PUBLIC ${CORE_PLATFORM_LIBS})
