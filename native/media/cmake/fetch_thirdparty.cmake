# ============================================================
# fetch_thirdparty.cmake
#
# 在 CMake 配置阶段下载并解压第三方源码。
# 提供统一的下载/编译接口，供各 platform/CMakeLists.txt 复用。
#
# 设计要点：
#   1. 用 ${CMAKE_CURRENT_LIST_FILE} 定位自己，所有路径都基于此解析。
#   2. 第三方产物放在 ${CMAKE_BINARY_DIR}/_thirdparty_build/ 统一管理。
#   3. 用 execute_process + curl/wget 而非 file(DOWNLOAD)，更可靠，支持重试。
# ============================================================

include(FetchContent)

# ============================================================
# 当前 helper 文件所在目录（绝对路径）
# ============================================================
get_filename_component(_THIRDPARTY_HELPER_DIR "${CMAKE_CURRENT_LIST_FILE}" ABSOLUTE)
get_filename_component(_THIRDPARTY_HELPER_DIR "${_THIRDPARTY_HELPER_DIR}" DIRECTORY)

# 第三方构建输出统一目录
set(_THIRDPARTY_DOWNLOAD_DIR
    "${CMAKE_BINARY_DIR}/_thirdparty_build"
    CACHE PATH "Third-party sources/build dir")

# 第三方库版本（与上游兼容）
set(_THIRDPARTY_VERSION_MINIZ  "2.2.0" CACHE STRING "miniz version (2.x = 单文件实现)")
set(_THIRDPARTY_VERSION_STB    "master" CACHE STRING "stb_image ref (branch/commit)")

# ============================================================
# 通用下载/解压 helper
# ============================================================
function(_thirdparty_download URL OUT_FILE)
    message(STATUS "[thirdparty] 下载 ${URL}")
    if(NOT EXISTS "${OUT_FILE}")
        # 确保目标目录存在（CMAKE_BINARY_DIR/_thirdparty_build 可能尚未创建）
        get_filename_component(_DOWNLOAD_PARENT "${OUT_FILE}" DIRECTORY)
        file(MAKE_DIRECTORY "${_DOWNLOAD_PARENT}")
        # 优先用 curl（更可靠，支持重试 + follow redirect）
        find_program(CURL_CMD curl)
        find_program(WGET_CMD wget)
        if(CURL_CMD)
            execute_process(
                COMMAND ${CURL_CMD} -fL --retry 3 --retry-delay 2 -o "${OUT_FILE}" "${URL}"
                RESULT_VARIABLE _r)
        elseif(WGET_CMD)
            execute_process(
                COMMAND ${WGET_CMD} --tries=3 -O "${OUT_FILE}" "${URL}"
                RESULT_VARIABLE _r)
        else()
            # fallback 到 CMake file(DOWNLOAD)
            file(DOWNLOAD "${URL}" "${OUT_FILE}"
                SHOW_PROGRESS
                STATUS _status)
            if(_status)
                message(FATAL_ERROR "[thirdparty] 下载失败: ${_status}")
            endif()
            set(_r 0)
        endif()
        if(NOT _r EQUAL 0)
            message(FATAL_ERROR "[thirdparty] 下载失败 (rc=${_r}): ${URL}")
        endif()
        if(NOT EXISTS "${OUT_FILE}")
            message(FATAL_ERROR "[thirdparty] 下载完成但未生成文件: ${URL}")
        endif()
    endif()
endfunction()

function(_thirdparty_extract ARCHIVE OUT_DIR)
    message(STATUS "[thirdparty] 解压 ${ARCHIVE} -> ${OUT_DIR}")
    file(REMOVE_RECURSE "${OUT_DIR}")
    file(MAKE_DIRECTORY "${OUT_DIR}")
    # 根据后缀选择解压命令
    get_filename_component(_ext "${ARCHIVE}" EXT)
    string(TOLOWER "${_ext}" _ext)
    if(_ext STREQUAL ".tar.gz" OR _ext STREQUAL ".tgz")
        execute_process(COMMAND tar -xzf "${ARCHIVE}" --strip-components=1 -C "${OUT_DIR}"
                        RESULT_VARIABLE _r)
    elseif(_ext STREQUAL ".tar.xz" OR _ext STREQUAL ".txz")
        execute_process(COMMAND tar -xf "${ARCHIVE}" --strip-components=1 -C "${OUT_DIR}"
                        RESULT_VARIABLE _r)
    elseif(_ext STREQUAL ".zip")
        execute_process(COMMAND unzip -q "${ARCHIVE}" -d "${OUT_DIR}"
                        RESULT_VARIABLE _r)
    else()
        message(FATAL_ERROR "[thirdparty] 不支持的归档格式: ${_ext}")
    endif()
    if(NOT _r EQUAL 0)
        message(FATAL_ERROR "[thirdparty] 解压失败 rc=${_r}: ${ARCHIVE}")
    endif()
endfunction()

# ============================================================
# miniz: ZIP/EPUB 压缩库（单文件 .c）
# ============================================================
function(thirdparty_setup_miniz)
    set(_MINIZ_DIR "${_THIRDPARTY_DOWNLOAD_DIR}/miniz-${_THIRDPARTY_VERSION_MINIZ}")
    if(NOT EXISTS "${_MINIZ_DIR}/miniz.c")
        _thirdparty_download(
            "https://github.com/richgel999/miniz/archive/refs/tags/${_THIRDPARTY_VERSION_MINIZ}.tar.gz"
            "${_THIRDPARTY_DOWNLOAD_DIR}/miniz.tar.gz")
        _thirdparty_extract("${_THIRDPARTY_DOWNLOAD_DIR}/miniz.tar.gz" "${_MINIZ_DIR}")
    endif()
    # miniz.h 需要 miniz_export.h（该文件由上游 CMake/amalgamate 生成）。
    # 本工程为静态库，导出宏为空即可，缺失时生成一个最小 stub。
    if(NOT EXISTS "${_MINIZ_DIR}/miniz_export.h")
        file(WRITE "${_MINIZ_DIR}/miniz_export.h"
"#pragma once\n/* 静态库构建 stub：无需符号导出，置空即可 */\n#define MINIZ_EXPORT\n")
    endif()
    set(THIRDPARTY_MINIZ_DIR "${_MINIZ_DIR}" PARENT_SCOPE)
    # miniz 2.x 拆分为多 TU：核心 + zip + 压缩 + 解压，需全部编入
    set(THIRDPARTY_MINIZ_SRCS "${_MINIZ_DIR}/miniz.c;${_MINIZ_DIR}/miniz_zip.c;${_MINIZ_DIR}/miniz_tdef.c;${_MINIZ_DIR}/miniz_tinfl.c" PARENT_SCOPE)
    set(THIRDPARTY_MINIZ_SRC  "${_MINIZ_DIR}/miniz.c" PARENT_SCOPE)
    set(THIRDPARTY_MINIZ_HDR  "${_MINIZ_DIR}/miniz.h" PARENT_SCOPE)
endfunction()

# ============================================================
# stb_image: 图片解码库（header-only）
# stb 仓库不维护可靠的发布 tag，直接按 pinned 提交下载单头文件
# ============================================================
function(thirdparty_setup_stb_image)
    set(_STB_DIR "${_THIRDPARTY_DOWNLOAD_DIR}/stb")
    if(NOT EXISTS "${_STB_DIR}/stb_image.h")
        get_filename_component(_STB_PARENT "${_STB_DIR}" DIRECTORY)
        file(MAKE_DIRECTORY "${_STB_PARENT}")
        _thirdparty_download(
            "https://raw.githubusercontent.com/nothings/stb/${_THIRDPARTY_VERSION_STB}/stb_image.h"
            "${_STB_DIR}/stb_image.h")
    endif()
    set(THIRDPARTY_STB_DIR "${_STB_DIR}"           PARENT_SCOPE)
    set(THIRDPARTY_STB_HDR "${_STB_DIR}/stb_image.h" PARENT_SCOPE)
endfunction()

# ============================================================
# FFmpeg：不在此处下载/编译源码。各平台链接预编译 FFmpeg：
#   - Linux:    系统包 (libavformat-dev 等) 经 pkg-config
#   - Windows:  CI 下载预编译 MSVC 库 (FFMPEG_DIR)
#   - Android:  CI 下载预编译各 ABI 库 (FFMPEG_DIR/<abi>)
#   - Apple:    CI 下载预编译 xcframework (FFMPEG_DIR)
# ============================================================
