import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';

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

/// 通过 media 静态库（stb_image）解码图片为 RGBA 并渲染。
class _CppImageWidget extends StatefulWidget {
  final String path;
  const _CppImageWidget({required this.path});

  @override
  State<_CppImageWidget> createState() => _CppImageWidgetState();
}

class _CppImageWidgetState extends State<_CppImageWidget> {
  ui.Image? _image;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final decoded = FileService().decodeImage(widget.path);
    if (decoded == null) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }
    // 将 media 静态库解码的 RGBA 字节转为 ui.Image 渲染
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      decoded.bytes,
      decoded.width,
      decoded.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final img = await completer.future;
    if (!mounted) return;
    setState(() {
      _image = img;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CircularProgressIndicator(color: Colors.white);
    if (_error || _image == null) {
      return const Icon(Icons.broken_image, color: Colors.white, size: 64);
    }
    return RawImage(image: _image, fit: BoxFit.contain);
  }
}
