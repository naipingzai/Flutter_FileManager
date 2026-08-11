import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/file_service.dart';

/// 图片查看器
class ImageViewerPage extends StatefulWidget {
  final String initialPath;
  final List<String> paths;
  final int initialIndex;

  const ImageViewerPage({
    super.key,
    required this.initialPath,
    this.paths = const [],
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late PageController _controller;
  late List<String> _paths;

  @override
  void initState() {
    super.initState();
    _paths = widget.paths.isNotEmpty ? widget.paths : [widget.initialPath];
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        title: Text(
          FileService.getFileName(
            _paths[_controller.hasClients
                ? _controller.page?.round() ?? widget.initialIndex
                : widget.initialIndex],
          ),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _paths.length,
        itemBuilder: (ctx, i) {
          return InteractiveViewer(
            child: Center(child: _CppImageWidget(path: _paths[i])),
          );
        },
        onPageChanged: (i) => setState(() {}),
      ),
    );
  }
}

/// Widget that loads images through the C++ backend (base64 encoded).
class _CppImageWidget extends StatelessWidget {
  final String path;
  const _CppImageWidget({required this.path});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: Future(() {
        final b64 = FileService().readImageAsBase64(path);
        if (b64 == null || b64.isEmpty) return null;
        return base64Decode(b64);
      }),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator(color: Colors.white);
        }
        if (snap.data == null) {
          return const Icon(Icons.broken_image, color: Colors.white, size: 64);
        }
        return Image.memory(snap.data!, fit: BoxFit.contain);
      },
    );
  }
}
