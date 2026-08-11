import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: Icon(Icons.folder_special, size: 80, color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          Center(child: Text('Flutter File Manager', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
          const SizedBox(height: 4),
          Center(child: Text('Flutter + C++ 版本', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
          const SizedBox(height: 4),
          Center(child: Text('版本 1.0.0', style: theme.textTheme.bodySmall)),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('项目信息', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(),
                  _infoRow('架构', 'Flutter (Dart) + C++ (FFI)'),
                  _infoRow('平台', 'Linux Desktop'),
                  _infoRow('UI 框架', 'Material Design 3'),
                  _infoRow('原生库', 'libfile_ops.so (POSIX API)'),
                  _infoRow('哈希算法', 'OpenSSL (MD5/SHA/SHA256/SHA512)'),
                  _infoRow('校验', 'zlib (CRC32)'),
                  _infoRow('文件遍历', 'std::filesystem + POSIX'),
                  _infoRow('许可证', 'GPL-3.0'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('功能特性', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(),
                  _feature('文件浏览 (列表/网格视图)'),
                  _feature('面包屑导航 + 标签页'),
                  _feature('文件操作 (新建/删除/重命名/复制/移动)'),
                  _feature('文件搜索 (glob 模式)'),
                  _feature('文件属性 (权限/所有者/类型)'),
                  _feature('校验和计算 (MD5/SHA1/SHA256/SHA512/CRC32)'),
                  _feature('重复文件查找'),
                  _feature('空文件/空目录查找'),
                  _feature('存储分析'),
                  _feature('符号链接检测'),
                  _feature('隐藏文件管理'),
                  _feature('排序 (名称/大小/时间/类型)'),
                  _feature('多选操作'),
                  _feature('书签管理'),
                  _feature('MIME 类型识别'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Text('Copyright (C) 2026 flutter-file-manager', style: theme.textTheme.bodySmall)),
          Center(child: Text('Licensed under GPL-3.0', style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _feature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
