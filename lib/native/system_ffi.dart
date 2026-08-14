// ignore_for_file: non_constant_identifier_names
//
// system_ffi - Dart FFI bindings for the native system module.
// 所有平台信息通过 C++ 获取，Dart 不直接调用 Platform.isXxx。

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// char* system_info(void)
typedef SystemInfoNative = Pointer<Utf8> Function();
typedef SystemInfoDart = Pointer<Utf8> Function();

// char* system_standard_dir(const char* category)
typedef SystemStandardDirNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef SystemStandardDirDart = Pointer<Utf8> Function(Pointer<Utf8>);

// void system_free_string(char* str)
typedef SystemFreeStringNative = Void Function(Pointer<Utf8>);
typedef SystemFreeStringDart = void Function(Pointer<Utf8>);

/// system 模块统一 FFI 封装。
/// Dart 层不做任何 Platform.isXxx 判断，所有路径/平台信息由 C++ 提供。
class SystemNative {
  static SystemNative? _instance;

  late final DynamicLibrary _lib;
  late final SystemInfoDart _systemInfo;
  late final SystemStandardDirDart _systemStandardDir;
  late final SystemFreeStringDart _systemFreeString;

  SystemNative._() {
    _lib = _loadLibrary();
    _systemInfo = _lib.lookupFunction<SystemInfoNative, SystemInfoDart>(
      'system_info',
    );
    _systemStandardDir = _lib.lookupFunction<SystemStandardDirNative,
        SystemStandardDirDart>('system_standard_dir');
    _systemFreeString = _lib.lookupFunction<SystemFreeStringNative,
        SystemFreeStringDart>('system_free_string');
  }

  factory SystemNative() {
    _instance ??= SystemNative._();
    return _instance!;
  }

  DynamicLibrary _loadLibrary() {
    // Android 打包为 .so 时需要显式 open；其余平台静态库集成进进程。
    if (Platform.isAndroid) return DynamicLibrary.open('libfileops.so');
    return DynamicLibrary.process();
  }

  /// 获取完整平台信息 JSON：
  /// {
  ///   "os": "...", "arch": "...", "path_separator": "...",
  ///   "user_home": "...", "root_dir": "...",
  ///   "downloads_dir": "...", "documents_dir": "...", ...
  /// }
  Map<String, dynamic> get info {
    final ptr = _systemInfo();
    final str = ptr.toDartString();
    _systemFreeString(ptr);
    return jsonDecode(str) as Map<String, dynamic>;
  }

  /// 获取指定标准目录的绝对路径（返回 malloc 字符串，此处负责释放）。
  String standardDir(String category) {
    final cat = category.toNativeUtf8();
    try {
      final ptr = _systemStandardDir(cat);
      final str = ptr.toDartString();
      _systemFreeString(ptr);
      return str;
    } finally {
      calloc.free(cat);
    }
  }

  /// 用户主目录
  String get homeDirectory {
    final info = this.info;
    return info['user_home'] as String? ?? '/';
  }

  /// 根目录
  String get rootDirectory {
    final info = this.info;
    return info['root_dir'] as String? ?? '/';
  }

  /// 平台名称（"windows" / "linux" / "macos" / "ios" / "android"）
  String get osName {
    final info = this.info;
    return info['os'] as String? ?? 'unknown';
  }
}