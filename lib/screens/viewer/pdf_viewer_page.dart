import 'package:flutter/material.dart';
import '../../services/file_service.dart';

/// PDF 查看器（APP 内部渲染，数据由 C++ 层读取）
class PdfViewerPage extends StatefulWidget {
  final String path;
  const PdfViewerPage({super.key, required this.path});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  bool _loading = true;
  String? _error;
  int _size = 0;
  String _header = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = FileService().readPdfData(widget.path);
      if (data == null) {
        setState(() { _loading = false; _error = '无法读取 PDF 文件'; });
        return;
      }
      _size = data.length;
      _header = String.fromCharCodes(data.take(8).toList());
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _error = '读取失败: $e'; });
    }
  }

  String _fmt(int b) {
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final name = FileService.getFileName(widget.path);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(name, textAlign: TextAlign.center),
                          const Divider(),
                          _row('文件大小', _fmt(_size)),
                          _row('文件头', _header.trim()),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Colors.grey)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
