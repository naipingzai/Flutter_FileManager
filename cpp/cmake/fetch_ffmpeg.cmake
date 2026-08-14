# ============================================================
# fetch_ffmpeg.cmake
# ============================================================
# 从 Flutter_CrossPlatformDependency 仓库的 Release 下载当前平台
# 的 FFmpeg 静态库，并解压到构建目录。
#
# 设计要点（遵循 skill 第 10~14 节）：
#   - APP 不编译 FFmpeg，只消费已发布的跨平台编译产物。
#   - 根据当前编译平台/ABI 自动选择对应 tarball 与子目录。
#   - 产物结构与依赖仓库一致：include/ + lib/<plat>/<arch>/
#
# 依赖仓库 Release 地址：
#   https://github.com/naipingzai/Flutter_CrossPlatformDependency/releases/download/ffmpeg-n7.1/
# 需先由依赖仓库 CI 发布 ffmpeg-n7.1 Release。
# ============================================================

include(${CMAKE_CURRENT_LIST_DIR}/fetch_thirdparty.cmake)

set(FFMPEG_RELEASE_TAG   "ffmpeg-n7.1"  CACHE STRING "FFmpeg release tag")
set(FFMPEG_RELEASE_BASE  "https://github.com/naipingzai/Flutter_CrossPlatformDependency/releases/download/${FFMPEG_RELEASE_TAG}")

# 解压后根目录（${CMAKE_BINARY_DIR}/_thirdparty_build/ffmpeg/<plat>/...）
set(_FFMPEG_OUT_ROOT "${_THIRDPARTY_DOWNLOAD_DIR}/ffmpeg")

# ============================================================
# fetch_ffmpeg()
# 根据平台下载并解压对应 tarball。
# 输出（PARENT_SCOPE）：
#   FFMPEG_INCLUDE_DIR   头文件目录
#   FFMPEG_LIB_DIR       静态库目录
#   FFMPEG_AVAILABLE     TRUE/FALSE
# ============================================================
function(fetch_ffmpeg)
    set(FFMPEG_AVAILABLE FALSE)

    # ---- 确定平台名 + tarball + 库子目录 ----
    if(WIN32)
        set(_plat "windows")
        set(_arch "x86_64")
    elseif(ANDROID)
        set(_plat "android")
        if(NOT ANDROID_ABI)
            set(_arch "${CMAKE_ANDROID_ARCH_ABI}")
        else()
            set(_arch "${ANDROID_ABI}")
        endif()
        if(NOT _arch)
            message(FATAL_ERROR "[ffmpeg] Android 未提供 ABI")
        endif()
    elseif(APPLE)
        # 区分 iOS 与 macOS
        if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
            set(_plat "ios")
            set(_arch "arm64")
        else()
            # 依赖仓库 macOS 仅出 arm64（Apple Silicon）
            set(_plat "macos")
            set(_arch "arm64")
        endif()
    else()
        set(_plat "linux")
        # aarch64 / x86_64
        string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _proc)
        if(_proc MATCHES "aarch64|arm64")
            set(_arch "aarch64")
        else()
            set(_arch "x86_64")
        endif()
    endif()

    set(_tar_name "ffmpeg-${_plat}.tar.gz")
    set(_url "${FFMPEG_RELEASE_BASE}/${_tar_name}")
    set(_archive "${_THIRDPARTY_DOWNLOAD_DIR}/${_tar_name}")

    # ---- 下载（失败不中断，回退到 FFmpeg 桩实现） ----
    if(NOT EXISTS "${_FFMPEG_OUT_ROOT}/${_plat}/${_arch}/lib")
        set(_dl_ok FALSE)
        file(MAKE_DIRECTORY "${_THIRDPARTY_DOWNLOAD_DIR}")
        find_program(_CURL curl)
        find_program(_WGET wget)
        if(_CURL)
            execute_process(COMMAND ${_CURL} -fL --retry 2 --retry-delay 2 -o "${_archive}" "${_url}"
                            RESULT_VARIABLE _r)
            if(_r EQUAL 0 AND EXISTS "${_archive}")
                set(_dl_ok TRUE)
            endif()
        elseif(_WGET)
            execute_process(COMMAND ${_WGET} --tries=2 -O "${_archive}" "${_url}"
                            RESULT_VARIABLE _r)
            if(_r EQUAL 0 AND EXISTS "${_archive}")
                set(_dl_ok TRUE)
            endif()
        endif()

        if(_dl_ok)
            # tarball 内部结构：<plat>/... （压缩时在 ffmpeg/ 目录下打包 <plat>）
            set(_extract_dir "${_THIRDPARTY_DOWNLOAD_DIR}/_ffmpeg_extract_${_plat}")
            _thirdparty_extract("${_archive}" "${_extract_dir}")
            if(EXISTS "${_extract_dir}/${_plat}")
                file(REMOVE_RECURSE "${_FFMPEG_OUT_ROOT}/${_plat}")
                file(MAKE_DIRECTORY "${_FFMPEG_OUT_ROOT}/${_plat}")
                file(COPY "${_extract_dir}/${_plat}/" DESTINATION "${_FFMPEG_OUT_ROOT}/${_plat}")
                file(REMOVE_RECURSE "${_extract_dir}")
            else()
                file(REMOVE_RECURSE "${_FFMPEG_OUT_ROOT}/${_plat}")
                file(COPY "${_extract_dir}/" DESTINATION "${_FFMPEG_OUT_ROOT}/${_plat}")
                file(REMOVE_RECURSE "${_extract_dir}")
            endif()
        else()
            # 清理可能存在的残缺下载文件
            file(REMOVE "${_archive}")
            message(WARNING
                "[ffmpeg] 下载失败: ${_url}\n"
                "        请先运行 Flutter_CrossPlatformDependency 仓库的\n"
                "        build_ffmpeg.yml 工作流发布 Release。本次回退到 FFmpeg 桩实现。")
        endif()
    endif()

    set(_lib_dir "${_FFMPEG_OUT_ROOT}/${_plat}/${_arch}/lib")
    set(_inc_dir "${_FFMPEG_OUT_ROOT}/${_plat}/${_arch}/include")

    # ---- Windows/MSVC：依赖仓库的 FFmpeg 为 MinGW 的 .a，MSVC 无法直接链接 ----
    # 用 llvm-lib 将 libav*.a 转换为 av*.lib（VS 2019+ 附带 LLVM 工具集）。
    if(WIN32 AND MSVC AND EXISTS "${_lib_dir}")
        find_program(_LLVM_LIB llvm-lib)
        if(_LLVM_LIB)
            file(GLOB _mingw_libs "${_lib_dir}/libav*.a")
            foreach(_a IN LISTS _mingw_libs)
                get_filename_component(_base "${_a}" NAME_WE)   # 去 lib 前缀与 .a 后缀
                string(REGEX REPLACE "^lib" "" _libname "${_base}")
                message(STATUS "[ffmpeg] 转换 ${_libname}.a -> ${_libname}.lib (llvm-lib)")
                execute_process(
                    COMMAND ${_LLVM_LIB} /machine:x64 "/out:${_lib_dir}/${_libname}.lib" "${_a}"
                    RESULT_VARIABLE _conv_r)
                if(NOT _conv_r EQUAL 0)
                    message(WARNING "[ffmpeg] 转换失败: ${_a}（回退，MSVC 链接可能报错）")
                endif()
            endforeach()
        else()
            message(WARNING
                "[ffmpeg] 未找到 llvm-lib。Windows/MSVC 需要 MinGW .a 转 .lib，
                         请安装 LLVM 工具集或改用 MinGW 工具链。")
        endif()
    endif()

    if(EXISTS "${_lib_dir}" AND EXISTS "${_inc_dir}")
        set(FFMPEG_AVAILABLE TRUE)
        message(STATUS "[ffmpeg] 使用 ${_plat}/${_arch} (${_lib_dir})")
    else()
        message(WARNING "[ffmpeg] 未找到产物: ${_lib_dir}（请先运行依赖仓库 CI 发布 Release）")
    endif()

    set(FFMPEG_INCLUDE_DIR "${_inc_dir}" PARENT_SCOPE)
    set(FFMPEG_LIB_DIR     "${_lib_dir}"  PARENT_SCOPE)
    set(FFMPEG_AVAILABLE   "${FFMPEG_AVAILABLE}" PARENT_SCOPE)
    set(FFMPEG_PLATFORM    "${_plat}" PARENT_SCOPE)
    set(FFMPEG_ARCH        "${_arch}" PARENT_SCOPE)
endfunction()
