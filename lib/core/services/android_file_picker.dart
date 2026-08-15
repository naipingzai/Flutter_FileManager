import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android 上用原生 SAF（ACTION_OPEN_DOCUMENT）选文件并返回真实路径。
///
/// 背景：file_selector_android 在选择文件时会读取整个文件内容到内存
/// （FileResponse.bytes），导入大文件会触发 OutOfMemoryError 崩溃。
/// 这里改为原生 SAF：只把所选文件拷贝到 app 缓存目录并返回路径，
/// 不读整个文件，彻底避免 OOM。
///
/// 非 Android 平台回退到 file_selector（桌面/iOS 无此问题）。
class AndroidFilePicker {
  static const MethodChannel _channel =
      MethodChannel('com.naipingzai.flutter_file_manager/file_picker');

  /// 选择文件，返回真实路径列表。
  static Future<List<String>> pickFiles({bool multiple = true}) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      final typeGroup = XTypeGroup(label: '任意文件', extensions: []);
      final files = multiple
          ? await openFiles(acceptedTypeGroups: [typeGroup])
          : [await openFile(acceptedTypeGroups: [typeGroup])];
      return files
          .whereType<XFile>()
          .map((f) => f.path)
          .where((p) => p.isNotEmpty)
          .toList();
    }
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('pickFiles');
      return ((result ?? const []))
          .map((e) => e.toString())
          .where((p) => p.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
