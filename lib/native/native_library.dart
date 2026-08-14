// ignore_for_file: non_constant_identifier_names
//
// native_library - 统一原生库加载器（不涉及任何平台判断）
//
// 遵循 skill：Dart 层不处理平台差异。这里用「先尝试打开 .so、失败回退到
// 进程符号表」的策略，屏蔽 Android(.so) 与桌面(静态链接进可执行文件)的差异，
// 不出现任何 Platform.isXxx。
//
// 所有 FFI 绑定文件统一通过 loadNativeLibrary() 获取 DynamicLibrary。

import 'dart:ffi';

/// 加载原生库。
///
/// - Android：`libfileops.so` 可被打开，直接用其符号。
/// - 桌面（Linux/macOS/Windows/iOS）：原生库静态链接进可执行文件，
///   打开 .so 会失败，回退到 `DynamicLibrary.process()` 查进程内符号。
DynamicLibrary loadNativeLibrary() {
  try {
    return DynamicLibrary.open('libfileops.so');
  } catch (_) {
    return DynamicLibrary.process();
  }
}
