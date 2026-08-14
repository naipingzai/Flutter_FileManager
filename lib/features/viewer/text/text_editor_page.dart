import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';

/// 文本编辑器
class TextEditorPage extends StatefulWidget {
  final String path;
  const TextEditorPage({super.key, required this.path});

  @override
  State<TextEditorPage> createState() => _TextEditorPageState();
}

class _TextEditorPageState extends State<TextEditorPage> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final text = FileService().readTextFile(widget.path);
      if (text != null) {
        _controller.text = text;
      }
    } catch (e) {
      _showSnack('读取失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      final err = FileService().writeTextFile(widget.path, _controller.text);
      if (err != null) {
        _showSnack('保存失败: $err');
      } else {
        setState(() => _hasChanges = false);
        _showSnack('已保存');
      }
    } catch (e) {
      _showSnack('保存失败: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final name = FileService.getFileName(widget.path);
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // 有未保存修改，询问是否放弃
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('未保存的更改'),
            content: const Text('是否放弃未保存的修改并离开？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('放弃'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(name),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
              tooltip: '保存',
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  onChanged: (_) => setState(() => _hasChanges = true),
                ),
              ),
      ),
    );
  }
}
