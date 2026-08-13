# native — C++ 原生层（静态库）

> 架构约定：**Dart 只负责 UI**，所有文件/多媒体能力由 **C++** 提供，并**编译为静态库**
> 直接集成进可执行文件（Android 打包为 `libfileops.so`，其余平台经 `DynamicLibrary.process()`
> 通过进程符号表查找）。

## 一、分层结构（code 层 / platform 层）

每个子库统一为两层，**不同平台各自维护一份编译配置**：

```
native/
├── CMakeLists.txt                 # 顶层：add_subdirectory(core) + add_subdirectory(media)
├── core/                          # 文件系统 + 文本读取
│   ├── include/fs.h               # 公共 C API（统一 fs_* / fs_text_* 前缀）
│   ├── src/                       # code 层：跨平台实现（无系统库依赖）
│   │   ├── file_ops.cpp           #   文件操作核心实现（file_ops_*，内部使用）
│   │   ├── file_ops_json.cpp      #   fs_* JSON 封装（Dart FFI 主入口）
│   │   ├── text_ops.cpp           #   fs_text_* 大文本读取器
│   │   ├── crypto_impl.h          #   内置 哈希/AES（无 OpenSSL/zlib 依赖）
│   │   └── fs_internal.h          #   内部实现声明（不对外导出）
│   └── platform/                  # platform 层：各平台单独 CMake 配置
│       ├── linux/CMakeLists.txt
│       ├── android/CMakeLists.txt
│       ├── apple/CMakeLists.txt
│       └── windows/CMakeLists.txt
└── media/                         # 多媒体解码（图片/电子书/视频/音频）
    ├── include/media.h
    ├── src/media.cpp              # code 层：stb_image / miniz / FFmpeg 解码
    ├── cmake/fetch_thirdparty.cmake  # 统一下载/编译第三方源码
    ├── platform/{linux,android,apple,windows}/CMakeLists.txt  # 平台层：各自编译规则
    └── platform/*/src/            # 平台层音频输出（ALSA/AAudio/AudioQueue/WASAPI）
```

### 层职责
- **code 层（`src/`）**：跨平台功能实现，只依赖 C++17 标准库 + 内置实现（哈希/AES 均为纯源码）。
  代码层通过 `#ifdef _WIN32` / `#ifdef HAVE_FFMPEG` 等宏区分可选能力，不写平台分支。
- **platform 层（`platform/<plat>/`）**：为当前编译平台补充源码、编译定义、系统/第三方依赖链接。
  由顶层库的 CMakeLists 按 `WIN32 / ANDROID / APPLE / else` 选择 include。

## 二、统一 C API（fs_* 前缀）

`core` 库对外只暴露一套 **`fs_*`** 命名空间的 C API，供 Dart FFI 绑定：

| 分组 | 前缀 | 说明 |
|------|------|------|
| 目录/文件 | `fs_list_directory` `fs_get_file_info` `fs_create_file` `fs_rename` `fs_copy_file` `fs_move_file` `fs_exists` `fs_is_directory` ... | 文件系统操作（JSON 返回） |
| 权限/链接 | `fs_access` `fs_chmod` `fs_chown` `fs_symlink` `fs_link` `fs_realpath` `fs_readlink` ... | POSIX 权限与链接 |
| 工具 | `fs_compute_hash` `fs_get_disk_usage` `fs_find_duplicates` `fs_find_empty_files` `fs_get_recent_files` `fs_split_file` `fs_merge_files` `fs_compare_files` `fs_text_stats` `fs_detect_encoding` | 文件工具 |
| 加解密 | `fs_encrypt_file` `fs_decrypt_file` | AES-256-CBC |
| 内容读取 | `fs_read_text_file` `fs_write_text_file` `fs_read_csv_file` `fs_read_hex_chunk` `fs_read_image_as_base64` `fs_read_binary_as_base64` | viewer 数据源 |
| 大文本读取 | `fs_text_create/open/read/read_line/...` | 句柄式行索引读取器 |
| 释放 | `fs_free_json` | 释放所有 `fs_*` 返回的 JSON |

> 底层 `file_ops_*` 核心实现改为**内部**符号（`src/fs_internal.h` 声明），不再作为公共 API，
> 统一对外命名消除了原 `file_ops_*` + `text_ops_*` 两套"ops"前缀的混乱。

Dart 侧对应绑定：`lib/native/core_bindings.dart`（`CoreNative`），服务层入口：
`lib/services/file_service.dart`（`FileService`）。

## 三、第三方库集成（下载源码 + 按平台编译）

第三方统一通过 **`media/cmake/fetch_thirdparty.cmake`** 在 CMake 配置阶段下载源码，
再由各平台 CMake 调用对应**编译规则**：

| 库 | 版本 | 用途 | 集成方式 |
|----|------|------|----------|
| `stb_image` | v2.28 | 图片解码 | header-only，`STB_IMAGE_IMPLEMENTATION` 编译定义 |
| `miniz` | 2.2.0 | EPUB / ZIP 压缩包 | 源码编入静态库（miniz.c + miniz_zip/tdef/tinfl.c） |
| `FFmpeg` | 系统/预编译 | 视频 / 音频解码 | 各平台链接**预编译** FFmpeg，不本地编译源码 |

### FFmpeg 按平台集成（均使用预编译库，不本地 configure/make）

| 平台 | FFmpeg 来源 | 链接方式 |
|------|------|----------|
| Linux | 系统包 `libavformat-dev libavcodec-dev libavutil-dev libswscale-dev libswresample-dev` | `pkg-config`（`PkgConfig::FFMPEG`） |
| Windows | CI 下载预编译 MSVC 库 | `FFMPEG_DIR/lib/av*.lib` |
| Android | CI 下载预编译各 ABI 库 | `FFMPEG_DIR/lib/<abi>/libav*.a` |
| iOS/macOS | CI 下载预编译库 | `FFMPEG_DIR/lib/libav*.a`（xcconfig force_load） |

`FFMPEG_DIR` 优先取 CMake `-D`，其次环境变量 `FFMPEG_DIR`。目录须含 `include/` 与对应 `lib/`。

`media.cpp` 通过 `LIBAVUTIL_VERSION_MAJOR` 判断，兼容 FFmpeg 5.1+ 的 `ch_layout` API 与旧版 `channels` API。

```bash
# 只构建 core（无需 FFmpeg）
./native/scripts/build_core.sh

# 完整构建 core + media（联网下载编译 FFmpeg）
cmake -S native -B build/native -DCMAKE_BUILD_TYPE=Release
cmake --build build/native -j$(nproc)
```

产物：`libcore.a` / `libmedia.a`，由 Flutter 各平台构建脚本链接进应用。
