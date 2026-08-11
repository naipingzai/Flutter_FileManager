import 'package:flutter/material.dart';
import '../../services/file_service.dart';

/// 电子书查看器，对应 Android viewer/ebook/EbookViewerActivity.kt
class EbookViewerPage extends StatelessWidget {
  final String path;
  const EbookViewerPage({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final name = FileService.getFileName(path);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.book, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(name),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => FileService().openFile(path),
              icon: const Icon(Icons.open_in_new),
              label: const Text('使用系统阅读器打开'),
            ),
          ],
        ),
      ),
    );
  }
}
