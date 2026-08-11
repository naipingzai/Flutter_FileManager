import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/file_manager_page.dart';

const _permissionChannel = MethodChannel(
  'com.example.flutter_file_manager/permissions',
);

void main() {
  runApp(const AdvanceFileManagerApp());
}

class AdvanceFileManagerApp extends StatelessWidget {
  const AdvanceFileManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advance File Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
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
    if (!Platform.isAndroid) return true;
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
    if (!Platform.isAndroid) return;
    try {
      await _permissionChannel.invokeMethod('openAllFilesAccessSettings');
    } catch (e) {
      // Fallback to generic app settings
      await openAppSettings();
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    if (!Platform.isAndroid) {
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
      return const FileManagerPage();
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_off, size: 64, color: Colors.grey),
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
