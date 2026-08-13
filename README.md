# Flutter File Manager

跨平台文件管理器（Linux / Android / Windows / iOS），**APP 内部打开所有类型文件**，不依赖系统外部程序。

## 架构

- **UI（Dart / Flutter）**：`lib/`（页面、widgets、状态管理、服务封装）
- **功能（C++）**：`native/`，编译为**静态库**直接集成进可执行文件
  - 代码层（`src/`，跨平台）+ 平台层（`platform/<plat>/`，各平台独立编译配置）
  - `core` 库：文件系统 + 大文本读取（统一 `fs_*` C API）
  - `media` 库：图片（stb_image）/ 电子书·压缩包（miniz）/ 视频·音频（FFmpeg，`MEDIA_ENABLE_FFMPEG` 可开关）
- 第三方源码由 `native/media/cmake/fetch_thirdparty.cmake` 下载并按平台编译（stb_image / miniz / FFmpeg）
- 详见 [native/README.md](native/README.md)

## 构建

本机：

```bash
flutter pub get
flutter build linux --release      # Linux 二进制
flutter build apk --release        # Android APK
flutter build windows --release    # Windows EXE
flutter build ios --release --no-codesign  # iOS 未签名，再手动打包 IPA
```

原生库单独构建见 `native/scripts/`（`build_core.sh` / `build_all.sh`）。

## 持续构建（GitHub Actions）

`.github/workflows/build.yml` 在 `main`/`master`/`develop` 分支 push 或 PR 时，并行编译四个平台产物：

| 平台 | 产物 | 说明 |
|------|------|------|
| Linux | 二进制 | 含 FFmpeg，功能完整 |
| Android | APK | fat APK（arm64 / armv7 / x86_64 / x86） |
| Windows | EXE | x64 |
| iOS | 未签名 IPA | 无需 Apple 开发者证书 |

产物以 GitHub Actions **Artifacts** 形式提供。也可在 Actions 页面手动触发（workflow_dispatch）。
