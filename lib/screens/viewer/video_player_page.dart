import 'package:flutter/material.dart';
import '../../services/file_service.dart';

/// 视频播放器
class VideoPlayerPage extends StatelessWidget {
  final String path;
  const VideoPlayerPage({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final name = FileService.getFileName(path);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(name),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => FileService().openFile(path),
              icon: const Icon(Icons.play_arrow),
              label: const Text('使用系统播放器打开'),
            ),
          ],
        ),
      ),
    );
  }
}
