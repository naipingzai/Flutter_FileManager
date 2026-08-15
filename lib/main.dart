import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_file_manager/core/native/media_ffi.dart';
import 'package:flutter_file_manager/core/native/system_ffi.dart';
import 'package:flutter_file_manager/core/services/database_service.dart';
import 'package:flutter_file_manager/core/services/ui_scale.dart';
import 'package:flutter_file_manager/core/theme/m3_theme.dart';
import 'package:flutter_file_manager/features/library/library_page.dart';

const _permissionChannel = MethodChannel(
  'com.example.flutter_file_manager/permissions',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android 上 C++ 的 app_data 依赖 $HOME 会落到根目录，无法写入。
  // 用 path_provider 获取正确的应用私有目录并传给数据库。
  if (SystemNative().osName == 'android') {
    try {
      final dir = await getApplicationDocumentsDirectory();
      DatabaseService.dataDirOverride = dir.path;
      SystemNative.appDocumentsDir = dir.path;
    } catch (_) {
      // 失败则回退
    }
  }
  runApp(const FlutterFileManagerApp());
}

class FlutterFileManagerApp extends StatelessWidget {
  const FlutterFileManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 触发 native 静态库的 FFI lookup，确保媒体解码符号加载到进程。
    // ignore: unused_local_variable
    final core = MediaNative();

    return MaterialApp(
      title: 'Flutter File Manager',
      debugShowCheckedModeBanner: false,
      theme: M3Theme.light(),
      darkTheme: M3Theme.dark(),
      themeMode: ThemeMode.system,
      // 应用"显示设置"的全局字体缩放 + 提供 UiScale 给子树（实时生效）
      builder: (context, child) => ValueListenableBuilder<UiScale>(
        valueListenable: UiScaleController.instance,
        builder: (context, scale, _) => UiScaleScope(
          controller: UiScaleController.instance,
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale.font)),
            child: child!,
          ),
        ),
      ),
      home: const PermissionWrapper(),
    );
  }
}

class PermissionWrapper extends StatefulWidget {
  const PermissionWrapper({super.key});

  @override
  State<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper> {
  bool _checking = true;
  bool _granted = false;
  String _statusMessage = '正在检查权限...';

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When returning from settings, re-check
    if (!_granted && !_checking) {
      _checkAndRequestPermissions();
    }
  }

  Future<bool> _isManageExternalStorageGranted() async {
    // 通过 C++ 获取平台信息，Dart 不做 Platform.isXxx 判断。
    if (SystemNative().osName != 'android') return true;
    try {
      return await _permissionChannel.invokeMethod<bool>(
            'isManageExternalStorageGranted',
          ) ??
          false;
    } catch (e) {
      // Fallback to permission_handler
      return await Permission.manageExternalStorage.isGranted;
    }
  }

  Future<void> _openAllFilesAccessSettings() async {
    // 通过 C++ 获取平台信息，Dart 不做 Platform.isXxx 判断。
    if (SystemNative().osName != 'android') return;
    try {
      await _permissionChannel.invokeMethod('openAllFilesAccessSettings');
    } catch (e) {
      // Fallback to generic app settings
      await openAppSettings();
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    // 通过 C++ 获取平台信息，Dart 不做 Platform.isXxx 判断。
    if (SystemNative().osName != 'android') {
      setState(() {
        _granted = true;
        _checking = false;
      });
      return;
    }

    setState(() {
      _checking = true;
      _statusMessage = '正在检查存储权限...';
    });

    // 1. Use platform-native check for MANAGE_EXTERNAL_STORAGE (Android 11+)
    if (await _isManageExternalStorageGranted()) {
      setState(() {
        _granted = true;
        _checking = false;
      });
      return;
    }

    // 2. MANAGE_EXTERNAL_STORAGE requires user action via system settings.
    //    permission_handler.request() won't show a dialog for this special permission.
    // Show the guidance UI and let the user open the dedicated settings page.
    setState(() {
      _granted = false;
      _checking = false;
      _statusMessage = '需要授予"所有文件访问"权限';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_statusMessage),
            ],
          ),
        ),
      );
    }

    if (_granted) {
      return const LibraryPage();
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              const Text(
                '需要存储权限',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '请在设置中授予"所有文件访问"权限，\n以便浏览和管理设备上的文件。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  // Open the dedicated "All files access" settings page
                  await _openAllFilesAccessSettings();
                  // When user comes back, re-check
                  if (mounted) {
                    _checkAndRequestPermissions();
                  }
                },
                icon: const Icon(Icons.settings),
                label: const Text('前往设置授予权限'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _checkAndRequestPermissions,
                icon: const Icon(Icons.refresh),
                label: const Text('重新检查'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
