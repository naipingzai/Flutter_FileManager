# 第三方依赖

本仓库不下载、不本地编译第三方库源码。所有跨平台第三方库以**预编译静态库**形式
vendor 在工程内 `third_party/<platform>/`，随仓库提交，编译时直接链接，无需下载。

## 各平台预编译库（third_party/<platform>/）

| 平台 | 目录 | 架构 |
|------|------|------|
| Linux | `third_party/linux` | x86_64 |
| Windows | `third_party/windows` | x86_64 |
| macOS | `third_party/macos` | arm64 |
| iOS | `third_party/ios` | arm64 |
| Android | `third_party/android` | arm64-v8a |

每个 `third_party/<platform>/` 内含：

```
third_party/<platform>/
├── include/          libav*/ 头文件 + miniz.h + stb_image.h
└── lib/              libavformat.a libavcodec.a libavutil.a
                      libswscale.a libswresample.a
                      libminiz.a libstb_image.a
```

## 库清单

| 库 | 版本 | 用途 | 静态库 |
|----|------|------|--------|
| FFmpeg | 7.1 | 视频/音频解码 | `libavformat.a libavcodec.a libavutil.a libswscale.a libswresample.a` |
| miniz | 2.2.0 | ZIP/EPUB | `libminiz.a` |
| stb_image | 固定提交 | 图片解码 | `libstb_image.a` |

> 预编译产物由 [Flutter_CrossPlatformDependency](https://github.com/naipingzai/Flutter_CrossPlatformDependency)
> 仓库生成并发布，本仓库按平台 vendor 后直接使用。若要更新某个平台的库，把新产物替换到
> 对应 `third_party/<platform>/` 即可（头文件与静态库需保持一致）。

## 构建

本地与 CI 均无需下载/设置环境变量：

```bash
flutter build linux --release        # Linux
flutter build apk --release          # Android
flutter build windows --release      # Windows
flutter build macos --release        # macOS
flutter build ios --release --no-codesign   # iOS
```
