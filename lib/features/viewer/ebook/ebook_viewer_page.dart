import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';

/// 电子书查看器（APP 内部渲染，使用 media 静态库 miniz 提取正文）
class EbookViewerPage extends StatefulWidget {
  final String path;
  const EbookViewerPage({super.key, required this.path});

  @override
  State<EbookViewerPage> createState() => _EbookViewerPageState();
}

class _EbookViewerPageState extends State<EbookViewerPage> {
  String? _text;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = FileService().readEbookText(widget.path);
    setState(() {
      _text = text;
      _loading = false;
      if (text == null) _error = '无法解析电子书内容';
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = FileService.getFileName(widget.path);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(_error!),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _text ?? '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ),
    );
  }
}
