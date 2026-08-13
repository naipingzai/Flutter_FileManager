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
| `FFmpeg` | 4.4.4 | 视频 / 音频解码 | 下载源码 → `configure` + `make` + `make install` → 链接 `.a` |

### FFmpeg 按平台编译规则
各 `media/platform/<plat>/CMakeLists.txt` 独立提供 FFmpeg 的 configure 参数与链接方式。
可用 CMake 选项 **`MEDIA_ENABLE_FFMPEG`** 统一开关（默认值因平台而异，见下表）：

| 平台 | 默认 | 说明 |
|------|------|------|
| Linux | **ON** | 已验证：本机 gcc 编译，功能完整 |
| iOS/macOS | OFF | FFmpeg 交叉编译尚未在本工程验证，默认关保证可构建 |
| Android | OFF | toolchain prefix 交叉编译未验证，默认关保证 APK 可构建 |
| Windows | OFF | mingw `.a` → MSVC 链接未打通，默认关保证 EXE 可构建 |

关闭 FFmpeg 时，`media` 仍导出 `media_video_*` / `media_decode_audio` / `media_audio_output_*`
桩符号，Dart FFI 可无条件绑定、不崩溃；对应 viewer 显示"当前平台不支持解码"。

- **Linux**：本机 gcc 编译，`--cc` 缺省；链接 `libavformat/libavcodec/libavutil/libswscale/libswresample.a`。
- **Android**：按 `ANDROID_ABI`（arm64-v8a / armeabi-v7a / x86_64 / x86）选择 host triplet，
  `--cc=${ANDROID_TOOLCHAIN_PREFIX}clang` 交叉编译；静态库循环依赖用 `--start-group/--end-group` 包裹。
- **Apple（macOS/iOS）**：clang；iOS 用 `--host=aarch64-apple-darwin --cc=clang --as=clang --ld=clang` 交叉编译。
- **Windows**：需 mingw/LLVM 工具链（GCC ABI），configure 由 CI 脚本执行，产物 `.a` 直接链接。

FFmpeg 均裁剪为**仅解码器 + 文件协议**（`--disable-encoders --disable-network --disable-avdevice` 等），
大幅缩小体积、去掉 x86 asm 以提升可移植性。

### 产物目录
第三方下载与构建统一输出到 `CMAKE_BINARY_DIR/_thirdparty_build/`（FFmpeg 输出到
`_ffmpeg_build_<平台>`），按平台/ABI 隔离，避免互相污染。

## 四、构建

核心库可独立于 FFmpeg 构建（见 `scripts/build_core.sh`）；完整 media（含 FFmpeg）需联网下载源码。

- Linux 依赖：`cmake`、`g++`、`make`、`tar`、`curl`（或 `wget`）。
- media/FFmpeg 额外依赖：`libssl-dev`、`zlib1g-dev`、`libasound2-dev`（Linux 音频）。

```bash
# 只构建 core（无需 FFmpeg）
./native/scripts/build_core.sh

# 完整构建 core + media（联网下载编译 FFmpeg）
cmake -S native -B build/native -DCMAKE_BUILD_TYPE=Release
cmake --build build/native -j$(nproc)
```

产物：`libcore.a` / `libmedia.a`，由 Flutter 各平台构建脚本链接进应用。
