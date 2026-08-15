# Flutter 跨平台 APP 原生架构与第三方依赖构建 Skill

## 1. Skill 目标

本 Skill 用于规范当前 APP 的整体跨平台架构设计。

核心目标：

> Dart 层完全不需要处理平台差异，所有平台相关逻辑统一下沉到 C++。Dart 通过 FFI 与 C++ 通信，C++ 对 Dart 提供统一接口；C++ 内部再按照 Core 功能规范和 Platform 平台实现进行分层。

支持的平台包括但不限于：

* Windows
* Linux
* macOS
* Android
* iOS

架构需要满足以下原则：

1. Dart 业务代码不使用平台条件判断。
2. Dart 不直接实现平台相关功能。
3. Dart 需要的平台信息统一通过 FFI 从 C++ 获取。
4. FFI 接口在所有平台保持一致。
5. C++ 上层功能设计保持一致。
6. C++ 底层根据不同平台实现具体能力。
7. 平台差异只能存在于 C++ 底层实现和编译配置中。
8. 第三方 C/C++ 库统一通过独立依赖仓库进行跨平台编译。
9. APP 仓库不负责复杂第三方库的跨平台编译，只消费已经编译好的产物。

---

# 2. 总体架构

整体调用关系如下：

```text
┌─────────────────────────────────────┐
│             Flutter / Dart          │
│                                     │
│   UI / State / Business Presentation│
│                                     │
│   不处理平台差异                     │
└─────────────────┬───────────────────┘
                  │
                  │ FFI
                  │ 统一 C ABI
                  ▼
┌─────────────────────────────────────┐
│              C++ API                │
│                                     │
│   对 Dart 提供统一接口               │
│   所有平台函数签名保持一致            │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│           C++ Feature Core          │
│                                     │
│   按功能模块设计                     │
│   文件 / 文本 / 媒体 / 数据库等       │
│                                     │
│   不直接依赖具体平台 API              │
└─────────────────┬───────────────────┘
                  │
                  │ 平台抽象接口
                  ▼
┌─────────────────────────────────────┐
│        Platform Implementation      │
│                                     │
│ Windows / Linux / macOS             │
│ Android / iOS                       │
│                                     │
│ 实现具体平台 API                     │
└─────────────────────────────────────┘
```

核心思想：

```text
Dart
 ↓
统一 FFI
 ↓
C++ 功能模块
 ↓
平台抽象
 ↓
Windows / Linux / macOS / Android / iOS
```

---

# 3. Dart 层设计规范

Dart 层只负责：

* Flutter UI
* 页面逻辑
* 状态管理
* 用户交互
* 调用 FFI
* 处理 C++ 返回的数据

Dart 层禁止承担：

* 平台目录判断
* 平台文件系统规则判断
* 平台路径拼接
* 平台 API 调用
* Windows/Linux/macOS/Android/iOS 条件业务实现
* 第三方原生库加载策略的业务差异

禁止出现这种业务设计：

```dart
if (Platform.isWindows) {
  ...
} else if (Platform.isAndroid) {
  ...
}
```

也不应该在业务代码中：

```dart
if (Platform.isWindows) {
  path = 'C:\\...';
}

if (Platform.isLinux) {
  path = '/home/...';
}
```

正确方式是：

```text
Dart
 ↓
通过 FFI 请求 C++
 ↓
C++ 根据当前系统获取正确结果
 ↓
返回统一数据
 ↓
Dart 直接显示和使用
```

例如获取系统目录：

```dart
final directories = nativeSystem.getDirectories();
```

Dart 不关心当前系统是：

```text
Windows
Linux
macOS
Android
iOS
```

只关心 C++ 返回：

```text
[
  {
    name: "Documents",
    path: "..."
  },
  {
    name: "Downloads",
    path: "..."
  }
]
```

路径规则和显示名称全部由 C++ 决定。

---

# 4. FFI 设计规范

FFI 是 Dart 与 C++ 的唯一统一边界。

FFI 层的职责是：

```text
Dart 数据
 ↕
C ABI 数据结构
 ↕
C++ Feature API
```

FFI 不负责业务逻辑。

FFI 层只负责：

1. 参数转换
2. 返回值转换
3. 生命周期管理
4. 错误码传递
5. 调用 C++ Core 功能

推荐结构：

```text
cpp/
├── ffi/
│   ├── common/
│   ├── system/
│   ├── file/
│   ├── text/
│   └── media/
```

例如：

```text
cpp/ffi/system/system_ffi.cpp
cpp/ffi/file/file_ffi.cpp
cpp/ffi/text/text_ffi.cpp
```

统一对 Dart 导出：

```cpp
extern "C" {
    ...
}
```

例如：

```cpp
extern "C" const char* system_get_documents_path();
```

不同平台都必须提供相同接口：

```text
Windows:
system_get_documents_path()

Linux:
system_get_documents_path()

Android:
system_get_documents_path()

iOS:
system_get_documents_path()
```

Dart 永远只调用：

```dart
systemGetDocumentsPath();
```

不得根据平台调用不同 API。

---

# 5. C++ Core 设计规范

## 5.1 Core 不是单独的一个目录

`Core` 是整个 C++ 代码的设计规范，而不是简单建立：

```text
cpp/core/
```

然后把所有代码放进去。

正确理解：

> C++ 每一个功能模块都应该具有自己的核心业务层，并且业务层通过统一的平台接口访问底层能力。

例如文件功能：

```text
file/
├── api/
├── core/
├── platform/
└── ffi/
```

文本功能：

```text
text/
├── api/
├── core/
├── platform/
└── ffi/
```

媒体功能：

```text
media/
├── api/
├── core/
├── platform/
└── ffi/
```

因此：

```text
Core 是设计思想
```

而不是：

```text
所有功能全部塞进一个 core 文件夹
```

---

## 5.2 功能模块标准结构

每个功能模块推荐按照以下结构设计：

```text
module/
├── include/
│   └── module/
│       ├── module_api.h
│       └── module_types.h
│
├── core/
│   ├── module_manager.cpp
│   ├── module_service.cpp
│   └── ...
│
├── platform/
│   ├── platform_module.h
│   ├── windows/
│   │   └── platform_module_windows.cpp
│   ├── linux/
│   │   └── platform_module_linux.cpp
│   ├── macos/
│   │   └── platform_module_macos.cpp
│   ├── android/
│   │   └── platform_module_android.cpp
│   └── ios/
│       └── platform_module_ios.cpp
│
└── ffi/
    └── module_ffi.cpp
```

调用关系：

```text
Dart
 ↓
module_ffi.cpp
 ↓
module_api
 ↓
module Core
 ↓
platform_module.h
 ↓
具体平台实现
```

---

# 6. C++ Platform 层设计

Platform 层负责所有真正的平台差异。

例如系统目录。

定义统一接口：

```cpp
class PlatformSystem {
public:
    virtual std::string documentsPath() = 0;
    virtual std::string downloadsPath() = 0;
    virtual std::string tempPath() = 0;
};
```

Windows：

```cpp
class WindowsPlatformSystem : public PlatformSystem {
public:
    std::string documentsPath() override;
    std::string downloadsPath() override;
    std::string tempPath() override;
};
```

Linux：

```cpp
class LinuxPlatformSystem : public PlatformSystem {
public:
    std::string documentsPath() override;
    std::string downloadsPath() override;
    std::string tempPath() override;
};
```

Android：

```cpp
class AndroidPlatformSystem : public PlatformSystem {
public:
    std::string documentsPath() override;
    std::string downloadsPath() override;
    std::string tempPath() override;
};
```

Core 层：

```cpp
std::string SystemService::documentsPath() {
    return platform_->documentsPath();
}
```

FFI：

```cpp
extern "C" const char* system_get_documents_path() {
    return SystemService::instance().documentsPath();
}
```

Dart：

```dart
final path = nativeSystem.documentsPath();
```

最终 Dart 完全不知道：

```text
documentsPath()
```

内部是：

```text
Windows API
Linux XDG
Android Storage API
iOS Sandbox
macOS NSSearchPath
```

---

# 7. 平台信息统一由 C++ 提供

如果 Dart 确实需要平台信息，不直接自行判断。

统一由 C++ 提供：

```text
system_get_platform()
system_get_directories()
system_get_home_path()
system_get_documents_path()
system_get_downloads_path()
system_get_temp_path()
system_get_path_separator()
```

例如：

```dart
final systemInfo = nativeSystem.getSystemInfo();
```

返回：

```text
{
  platform: "windows",
  pathSeparator: "\\",
  directories: [...]
}
```

或者 Dart 直接请求具体数据：

```dart
final directories = nativeSystem.getDirectories();
```

优先原则：

> 如果 Dart 只是为了做业务而判断平台，应该重新设计，让 C++ 直接返回业务需要的数据。

例如错误设计：

```dart
if (platform == 'windows') {
  return 'Documents';
} else {
  return '文档';
}
```

正确设计：

```dart
final directories = nativeSystem.getDirectories();
```

C++ 返回：

```text
name: "文档"
path: "..."
type: documents
```

---

# 8. C++ 编译规范

APP 的 C++ 代码使用统一 CMake 构建入口。

推荐：

```text
cpp/
├── CMakeLists.txt
├── cmake/
│   ├── platform.cmake
│   ├── dependencies.cmake
│   └── options.cmake
│
├── modules/
├── ffi/
└── platform/
```

只有一个主编译入口：

```text
cpp/CMakeLists.txt
```

在编译文件中识别平台：

```cmake
if(WIN32)

elseif(APPLE)

elseif(ANDROID)

elseif(UNIX)

endif()
```

但是业务代码中尽量不通过：

```cpp
#ifdef _WIN32
```

直接处理大量业务差异。

正确方式：

```text
CMake
 ↓
根据平台选择源文件
 ↓
编译对应 Platform Implementation
 ↓
Core 使用统一接口
```

例如：

```cmake
if(WIN32)
    target_sources(native_core PRIVATE
        platform/windows/platform_system_windows.cpp
    )

elseif(ANDROID)
    target_sources(native_core PRIVATE
        platform/android/platform_system_android.cpp
    )

elseif(APPLE)
    target_sources(native_core PRIVATE
        platform/macos/platform_system_macos.cpp
    )

elseif(UNIX)
    target_sources(native_core PRIVATE
        platform/linux/platform_system_linux.cpp
    )
endif()
```

这样：

```text
业务逻辑代码不区分平台
```

平台选择集中在：

```text
CMake
```

平台实现集中在：

```text
platform/
```

---

# 9. 第三方库跨平台依赖仓库

第三方原生依赖统一使用独立仓库：

[Flutter_CrossPlatformDependency](https://github.com/naipingzai/Flutter_CrossPlatformDependency?utm_source=chatgpt.com)

仓库职责：

```text
Flutter_CrossPlatformDependency
```

专门负责：

* 获取第三方源码
* 配置第三方库版本
* 配置不同平台编译规则
* 编译 Windows 静态库
* 编译 Linux 静态库
* 编译 macOS 静态库
* 编译 Android 静态库
* 编译 iOS 静态库
* 通过 GitHub Actions 自动构建
* 发布或保存跨平台编译产物

APP 仓库不应该重复维护复杂第三方库的跨平台编译逻辑。

架构：

```text
┌─────────────────────────────────────┐
│ Flutter_CrossPlatformDependency     │
│                                     │
│ 第三方库源码获取                     │
│ 第三方库跨平台编译                   │
│ GitHub Actions                      │
│                                     │
│ 输出各平台静态库                     │
└─────────────────┬───────────────────┘
                  │
                  │ 编译产物
                  ▼
┌─────────────────────────────────────┐
│               APP                   │
│                                     │
│ CMake 使用对应平台产物               │
│                                     │
│ Dart → FFI → C++ → 第三方库          │
└─────────────────────────────────────┘
```

---

# 10. FFmpeg 依赖处理规范

第一阶段优先处理 FFmpeg。

目标：

> 在 Flutter_CrossPlatformDependency 仓库中建立 FFmpeg 的完整跨平台依赖配置，通过 GitHub Workflow 编译所有目标平台的静态库，当前 APP 后续直接使用编译产物。

支持目标：

```text
Windows
Linux
macOS
Android
iOS
```

FFmpeg 编译流程：

```text
FFmpeg Source
      ↓
Flutter_CrossPlatformDependency
      ↓
平台编译规则
      ↓
GitHub Actions
      ↓
Windows 静态库
Linux 静态库
macOS 静态库
Android 静态库
iOS 静态库
      ↓
Artifact / Release
      ↓
当前 APP 下载或引用
      ↓
CMake Link
```

---

# 11. 第三方依赖仓库推荐结构

推荐：

```text
Flutter_CrossPlatformDependency/
├── dependencies/
│   └── ffmpeg/
│       ├── dependency.yaml
│       ├── source/
│       ├── scripts/
│       │   ├── build_windows.sh
│       │   ├── build_linux.sh
│       │   ├── build_macos.sh
│       │   ├── build_android.sh
│       │   └── build_ios.sh
│       │
│       └── cmake/
│           └── ...
│
├── toolchains/
│   ├── android.cmake
│   ├── ios.cmake
│   └── ...
│
├── output/
│   └── ffmpeg/
│       ├── windows/
│       ├── linux/
│       ├── macos/
│       ├── android/
│       └── ios/
│
└── .github/
    └── workflows/
        └── build_ffmpeg.yml
```

未来新增：

```text
dependencies/
├── ffmpeg/
├── sqlite/
├── openssl/
├── libarchive/
└── ...
```

每一个第三方库遵循相同规范。

---

# 12. 第三方依赖配置规范

每个依赖应该具备统一配置描述。

例如：

```yaml
name: ffmpeg
version: x.x.x

platforms:
  windows:
    enabled: true

  linux:
    enabled: true

  macos:
    enabled: true

  android:
    enabled: true

  ios:
    enabled: true

build:
  type: static
```

后续 APP 不需要理解 FFmpeg 如何编译。

APP 只需要知道：

```text
FFmpeg
版本
当前平台
include 路径
lib 路径
```

例如：

```text
third_party/
└── ffmpeg/
    ├── include/
    └── lib/
```

或者由 CMake 自动获取：

```cmake
find_package(FFmpeg REQUIRED)
```

最终目标：

> APP 只消费第三方依赖产物，不维护第三方库跨平台编译过程。

---

# 13. GitHub Actions 编译规范

FFmpeg 通过 GitHub Actions 自动构建。

Workflow 根据平台拆分：

```text
build_ffmpeg.yml
│
├── Windows Job
├── Linux Job
├── macOS Job
├── Android Job
└── iOS Job
```

每个平台 Job：

```text
Checkout
 ↓
获取 FFmpeg 源码
 ↓
安装平台依赖
 ↓
执行平台编译规则
 ↓
生成静态库
 ↓
整理 include
 ↓
整理 lib
 ↓
上传 Artifact
```

最终统一输出格式。

例如：

```text
ffmpeg/
├── windows-x64/
│   ├── include/
│   └── lib/
│
├── linux-x64/
│   ├── include/
│   └── lib/
│
├── macos-arm64/
│   ├── include/
│   └── lib/
│
├── android-arm64-v8a/
│   ├── include/
│   └── lib/
│
├── android-armeabi-v7a/
│   ├── include/
│   └── lib/
│
├── ios-arm64/
│   ├── include/
│   └── lib/
```

---

# 14. 当前 APP 使用第三方库

当前 APP 的 CMake 根据编译平台选择依赖产物。

结构：

```text
APP/
├── cpp/
│   ├── CMakeLists.txt
│   └── ...
│
└── third_party/
    └── ffmpeg/
```

CMake：

```text
检测当前平台
 ↓
选择对应 FFmpeg include
 ↓
选择对应 FFmpeg 静态库
 ↓
Link 到 APP Native Library
```

例如：

```cmake
if(WIN32)
    set(FFMPEG_ROOT ...)
elseif(ANDROID)
    set(FFMPEG_ROOT ...)
elseif(APPLE)
    set(FFMPEG_ROOT ...)
elseif(UNIX)
    set(FFMPEG_ROOT ...)
endif()
```

APP 内部代码：

```cpp
#include <libavformat/avformat.h>
```

不需要：

```cpp
#ifdef WINDOWS
    ...
#elif ANDROID
    ...
#endif
```

除非 FFmpeg API 本身存在不可避免的平台能力差异。

---

# 15. 当前 APP C++ 总体规范

推荐未来代码组织：

```text
cpp/
├── CMakeLists.txt
│
├── common/
│   ├── error/
│   ├── types/
│   ├── result/
│   └── utils/
│
├── modules/
│   ├── system/
│   │   ├── api/
│   │   ├── core/
│   │   ├── platform/
│   │   └── ffi/
│   │
│   ├── file/
│   │   ├── api/
│   │   ├── core/
│   │   ├── platform/
│   │   └── ffi/
│   │
│   ├── text/
│   │   ├── api/
│   │   ├── core/
│   │   ├── platform/
│   │   └── ffi/
│   │
│   └── media/
│       ├── api/
│       ├── core/
│       ├── platform/
│       └── ffi/
│
└── platform/
    ├── windows/
    ├── linux/
    ├── macos/
    ├── android/
    └── ios/
```

注意：

```text
platform/
```

可以根据实际复杂度设计为：

### 模块内 Platform

```text
modules/file/platform/
modules/text/platform/
modules/media/platform/
```

适合模块平台差异较大。

或者：

### 全局 Platform

```text
platform/windows/
platform/linux/
platform/android/
```

适合统一管理平台服务。

推荐原则：

> 平台实现属于哪个功能模块，就优先放在哪个模块附近；多个模块共享的平台能力再放入全局 Platform。

---

# 16. 模块间依赖规范

模块依赖应该单向。

推荐：

```text
common
  ↑
system
  ↑
file
  ↑
text
  ↑
media
```

避免：

```text
file ↔ text
```

双向依赖。

模块之间如果需要公共能力：

```text
module A
    ↓
Common Interface
    ↑
module B
```

不要直接互相访问内部实现。

例如：

```text
file 模块
```

不能直接调用：

```text
text/core/private_xxx.cpp
```

只能调用：

```text
text API
```

---

# 17. 错误处理规范

Dart 不应该解析 C++ 平台异常。

统一由 C++ 转换为标准错误结果。

例如：

```text
Result<T>
```

包含：

```text
success
errorCode
errorMessage
```

FFI 层统一暴露。

Dart：

```dart
final result = nativeFile.open(path);

if (!result.success) {
  showError(result.errorMessage);
}
```

Dart 不需要知道：

```text
Windows GetLastError
errno
Android JNI Exception
iOS NSError
```

这些全部由 C++ 平台实现处理。

---

# 18. 生命周期规范

涉及 Native Object 的功能使用统一 Handle。

例如：

```text
Dart
 ↓
create
 ↓
Native Handle
 ↓
read / write / seek
 ↓
destroy
```

FFI：

```cpp
void* text_ops_create();
void text_ops_destroy(void* handle);
```

Dart：

```dart
final handle = textOps.create();

try {
  ...
} finally {
  textOps.destroy(handle);
}
```

所有模块遵循：

```text
create
destroy
```

避免 Dart 直接管理 C++ 内部对象。

---

# 19. 第一阶段实施顺序

## 第一阶段：FFmpeg 跨平台依赖

优先完成：

```text
Flutter_CrossPlatformDependency
```

任务：

* [ ] 拉取并整理 Flutter_CrossPlatformDependency 仓库
* [ ] 建立第三方依赖统一目录规范
* [ ] 建立 FFmpeg 依赖配置
* [ ] 确定 FFmpeg 版本
* [ ] 配置 FFmpeg 静态库编译
* [ ] 配置 Windows 编译
* [ ] 配置 Linux 编译
* [ ] 配置 macOS 编译
* [ ] 配置 Android ABI 编译
* [ ] 配置 iOS 编译
* [ ] 编写 GitHub Actions Workflow
* [ ] 自动生成各平台 Artifact
* [ ] 统一各平台 include/lib 输出结构
* [ ] 当前 APP 可以下载或获取 FFmpeg 编译产物
* [ ] 当前 APP CMake 可以链接 FFmpeg

第一阶段完成标准：

> 不需要在 APP 本地手动编译 FFmpeg，只需要获取对应平台的产物即可使用。

---

# 20. 第二阶段：整理 APP C++ 架构

完成 FFmpeg 依赖体系后，开始整理当前 APP。

任务：

* [ ] 确定 C++ 统一 CMake 入口
* [ ] 清理现有平台相关逻辑
* [ ] 建立统一 Common 基础层
* [ ] 按功能重新划分 C++ 模块
* [ ] 为每个模块建立统一 API
* [ ] 建立模块 Core 业务层
* [ ] 建立 Platform 抽象接口
* [ ] 实现各平台 Platform 层
* [ ] 建立统一 FFI 导出层
* [ ] Dart 移除业务中的平台判断
* [ ] Dart 平台信息统一从 C++ 获取
* [ ] 统一错误处理
* [ ] 统一 Native Handle 生命周期

重点：

> Core 不作为一个单独的大杂烩目录，而是作为每个功能模块的内部架构规范。

---

# 21. 最终架构原则

最终必须遵守以下规则。

### Dart

```text
不知道底层具体平台实现
```

### FFI

```text
所有平台接口一致
```

### C++ Feature Core

```text
负责功能和业务规则
```

### Platform

```text
负责 Windows / Linux / macOS / Android / iOS 差异
```

### CMake

```text
负责选择当前平台的实现和依赖
```

### Flutter_CrossPlatformDependency

```text
负责第三方原生库跨平台编译
```

### APP

```text
只消费第三方库跨平台编译产物
```

最终模型：

```text
┌──────────────────────────┐
│        Flutter Dart      │
│                          │
│     UI / State / Logic   │
│     无平台业务差异        │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│           FFI            │
│       统一 C ABI          │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│      C++ Feature Core    │
│                          │
│  File / Text / Media     │
│  System / Database ...   │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│    Platform Interface    │
└────────────┬─────────────┘
             │
     ┌───────┼────────┬────────┐
     ▼       ▼        ▼        ▼
 Windows   Linux    Android   Apple
                              │
                         macOS / iOS
```

第三方依赖：

```text
Flutter_CrossPlatformDependency
             │
             ▼
       GitHub Actions
             │
             ▼
    各平台静态库 Artifact
             │
             ▼
        当前 APP CMake
             │
             ▼
          C++ Core
             │
             ▼
            FFI
             │
             ▼
           Dart
```

**最终目标：平台差异只存在于 C++ 的 Platform 实现和构建配置中；Dart、FFI 和上层功能设计全部保持统一。**
