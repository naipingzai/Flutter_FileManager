// ignore_for_file: non_constant_identifier_names
//
// system_ffi - 平台信息/系统路径服务（纯 Dart 实现）。
// 用 dart:io Platform 与 path_provider 提供，不再依赖 native (FFmpeg) 层。

import 'dart:io';

import 'package:flutter/foundation.dart';

/// 平台信息与标准目录查询。
/// 接口与原 SystemNative 保持一致（osName / info / standardDir / homeDirectory /
/// rootDirectory），但底层用 Dart 实现，无需原生库。
class SystemNative {
  static SystemNative? _instance;

  /// 应用文档目录（由 path_provider 在 main 启动时缓存；桌面用 Platform 兜底）。
  static String? appDocumentsDir;

  SystemNative._();

  factory SystemNative() {
    _instance ??= SystemNative._();
    return _instance!;
  }

  /// 完整平台信息。
  /// { "os", "arch", "path_separator", "user_home", "root_dir",
  ///   "downloads_dir", "documents_dir", ... }
  Map<String, dynamic> get info {
    final home = homeDirectory;
    return {
      'os': osName,
      'arch': _arch,
      'path_separator': Platform.pathSeparator,
      'user_home': home,
      'root_dir': rootDirectory,
      'downloads_dir': _envDir(['DOWNLOAD', 'XDG_DOWNLOAD_DIR'], 'Downloads'),
      'documents_dir': _envDir(['XDG_DOCUMENTS_DIR'], 'Documents'),
      'desktop_dir': _envDir(['XDG_DESKTOP_DIR'], 'Desktop'),
      'app_data_dir': appDocumentsDir ?? '$home/.flutter_app_data',
    };
  }

  String get _arch {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return Platform.version.contains('arm64') ? 'aarch64' : 'arm';
      default:
        return 'x86_64';
    }
  }

  String _envDir(List<String> envKeys, String fallback) {
    for (final k in envKeys) {
      final v = Platform.environment[k];
      if (v != null && v.isNotEmpty) return v;
    }
    return '$homeDirectory/$fallback';
  }

  /// 指定标准目录的绝对路径。
  /// category: app_data / documents / downloads / home / root / cache / temp
  String standardDir(String category) {
    switch (category) {
      case 'app_data':
        return appDocumentsDir ?? '$homeDirectory/.flutter_app_data';
      case 'documents':
        return _envDir(['XDG_DOCUMENTS_DIR'], 'Documents');
      case 'downloads':
        return _envDir(['DOWNLOAD', 'XDG_DOWNLOAD_DIR'], 'Downloads');
      case 'desktop':
        return _envDir(['XDG_DESKTOP_DIR'], 'Desktop');
      case 'home':
        return homeDirectory;
      case 'root':
        return rootDirectory;
      case 'cache':
        return appDocumentsDir != null ? '$appDocumentsDir/.cache' : '${homeDirectory}/.cache';
      case 'temp':
        return Directory.systemTemp.path;
      default:
        return homeDirectory;
    }
  }

  /// 用户主目录。
  String get homeDirectory {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) return home;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return appDocumentsDir ?? '/data/user/0/';
    }
    return Platform.environment['USERPROFILE'] ?? '/';
  }

  /// 根目录。
  String get rootDirectory {
    if (defaultTargetPlatform == TargetPlatform.android) return '/';
    final root = Platform.environment['SystemDrive'];
    if (root != null && root.isNotEmpty) return root;
    return '/';
  }

  /// 平台名称（"windows" / "linux" / "macos" / "ios" / "android"）。
  String get osName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }
}
