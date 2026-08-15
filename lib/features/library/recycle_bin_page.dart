import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/database_service.dart';

/// 回收站页（design_skill 13b.1，模式 A）
/// 文件列表（可多选恢复/彻底删除）+ 右下角清空按钮
class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _files = [];
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _files = _db.listDeleted();
      _selected.clear();
    });
  }

  String _size(dynamic v) {
    final n = (v is int) ? v : (v?.toInt() ?? 0);
    if (n < 1024) return '$n B';
    if (n < 1048576) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        actions: [
          if (_selected.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.settings_backup_restore),
              tooltip: '恢复',
              onPressed: _restoreSelected,
            ),
            IconButton(
              icon: Icon(Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error),
              tooltip: '彻底删除',
              onPressed: _deleteSelected,
            ),
          ],
        ],
      ),
      floatingActionButton: _files.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _emptyTrash,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('清空'),
            ),
      body: _files.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('回收站为空',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _files.length,
              itemBuilder: (ctx, i) {
                final f = _files[i];
                final id = f['id'] as int;
                final isDir = (f['isDir'] ?? 0) == 1;
                final isSel = _selected.contains(id);
                return ListTile(
                  leading: Icon(
                    isDir ? Icons.folder : _typeIcon(f['ext']),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(f['name'].toString(),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_size(f['size'])),
                  trailing: isSel
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                  selected: isSel,
                  onTap: () {
                    setState(() {
                      if (isSel) {
                        _selected.remove(id);
                      } else {
                        _selected.add(id);
                      }
                    });
                  },
                );
              },
            ),
    );
  }

  void _restoreSelected() {
    for (final id in _selected) {
      _db.restore(id);
    }
    _snack('已恢复 ${_selected.length} 项');
    _reload();
  }

  Future<void> _deleteSelected() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('彻底删除'),
        content: Text('确定彻底删除选中的 ${_selected.length} 项？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      for (final id in _selected) {
        _db.purge(id);
      }
      _snack('已删除 ${_selected.length} 项');
      _reload();
    }
  }

  Future<void> _emptyTrash() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空回收站'),
        content: const Text('确定清空回收站？所有文件将被彻底删除，不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _db.emptyTrash();
      _snack('回收站已清空');
      _reload();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  IconData _typeIcon(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Icons.image;
      case 'mp4':
      case 'mkv':
      case 'mov':
      case 'webm':
        return Icons.movie;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'ogg':
        return Icons.music_note;
      case 'pdf':
        return Icons.picture_as_pdf;
      default:
        return Icons.insert_drive_file;
    }
  }
}
