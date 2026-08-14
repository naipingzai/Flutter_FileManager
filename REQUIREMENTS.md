# 第三方依赖需求清单

本仓库**不在构建期下载并编译第三方库源码**，也不 vendor 第三方源码。
所有跨平台第三方库统一由 **Flutter_CrossPlatformDependency** 仓库编译成
预编译静态库，本仓库通过 `THIRDPARTY_DIR` 直接链接产物。

## 需要你（Flutter_CrossPlatformDependency）编译的第三方库

| 库 | 版本 | 用途 | 需要的静态库 | 需要头文件 |
|----|------|------|--------------|-----------|
| **FFmpeg** | 7.x（建议 7.1） | 视频/音频解码 | `libavformat.a libavcodec.a libavutil.a libswscale.a libswresample.a` | `libavformat/... libavcodec/... libavutil/... libswscale/... libswresample/...` |
| **miniz** | 2.x（建议 2.2.0） | ZIP/EPUB 压缩解压 | `libminiz.a` | `miniz.h` |
| **stb_image** | stb 2.x | 图片解码 | `libstb_image.a` | `stb_image.h` |

> 注意：
> - stb_image 静态库需把 `STB_IMAGE_IMPLEMENTATION` 定义在 stb_image.c 中编译为独立 TU，
>   不要在本仓库 media_core.cpp 里再定义实现（本仓库只包含声明并链接 `libstb_image.a`）。
> - miniz 2.x 多 TU（miniz.c/miniz_zip.c/miniz_tdef.c/miniz_tinfl.c）需合并进 `libminiz.a`。

## 各平台架构

| 平台 | 架构 |
|------|------|
| Linux | `x86_64`（也可 `aarch64`） |
| Windows | `x86_64` |
| macOS | `arm64` |
| iOS | `arm64` |
| Android | `arm64-v8a` |

## 产物目录结构（THIRDPARTY_DIR）

每个平台一份，目录结构固定：

```
${THIRDPARTY_DIR}/
├── include/
│   ├── libavformat/  libavcodec/  libavutil/  libswscale/  libswresample/
│   ├── miniz.h   miniz_common.h  miniz_export.h  miniz_tdef.h  miniz_tinfl.h  miniz_zip.h
│   └── stb_image.h
└── lib/
    ├── libavformat.a  libavcodec.a  libavutil.a
    ├── libswscale.a   libswresample.a
    ├── libminiz.a
    └── libstb_image.a
```

> miniz.h 依赖同目录的 `miniz_common.h` / `miniz_export.h` / `miniz_tdef.h` / `miniz_tinfl.h` / `miniz_zip.h`，
> 需随 `miniz.h` 一并放入 `include/`。
```

## 构建时提供 THIRDPARTY_DIR

```bash
# Linux
export THIRDPARTY_DIR=/path/to/thirdparty/linux/x86_64
flutter build linux --release

# Android（arm64-v8a 一份）
export THIRDPARTY_DIR=/path/to/thirdparty/android/arm64-v8a
flutter build apk --release
```

未设置 `THIRDPARTY_DIR` 时，构建回退到桩实现（媒体解码不可用），其余功能正常。
CI 工作流 `.github/workflows/build.yml` 会按平台下载预编译产物并设置 `THIRDPARTY_DIR`。
