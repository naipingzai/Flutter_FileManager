import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/database_service.dart';

/// 文件库页面：基于数据库的导入式文件管理 + 标签系统（核心）
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _tags = [];
  int? _filterTagId;
  final Set<int> _selected = {}; // 多选的文件 id
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _tags = _db.tags();
      _files = _filterTagId == null ? _db.listAll() : _db.filesByTag(_filterTagId!);
    });
  }

  Future<void> _import() async {
    const typeGroup = XTypeGroup(label: '任意文件', extensions: []);
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return;
    final src = file.path;
    if (src.isEmpty) return;
    final result = _db.importFile(src);
    if (result == null) {
      _snack('导入失败');
    } else {
      _snack('已导入: ${result['name']}');
    }
    _load();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createTag() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建标签'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '标签名'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('创建')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      _db.createTag(name);
      _load();
    }
  }

  Future<void> _addTagsToSelected() async {
    if (_selected.isEmpty) return;
    final selected = _selected.toList();
    final tags = _db.tags().where((t) => (t['builtin'] ?? 0) == 0).toList();
    final chosen = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _TagPickerDialog(tags: tags),
    );
    if (chosen != null && chosen.isNotEmpty) {
      final added = _db.addTagsToFiles(selected, chosen.toList());
      _snack('已为 ${selected.length} 个文件添加标签（新增 $added 条）');
      setState(() => _selected.clear());
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '导入文件',
            onPressed: _import,
          ),
          IconButton(
            icon: const Icon(Icons.new_label_outlined),
            tooltip: '新建标签',
            onPressed: _createTag,
          ),
          if (_selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sell_outlined),
              tooltip: '批量加标签',
              onPressed: _addTagsToSelected,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildTagBar(),
          const Divider(height: 1),
          Expanded(child: _buildFileList()),
        ],
      ),
    );
  }

  Widget _buildTagBar() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        children: [
          _tagChip(null, '全部', _filterTagId == null),
          for (final t in _tags) _tagChip(t['id'], t['name'], _filterTagId == t['id']),
        ],
      ),
    );
  }

  Widget _tagChip(dynamic id, String name, bool selected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(name),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _filterTagId = id as int?;
            _load();
          });
        },
      ),
    );
  }

  Widget _buildFileList() {
    if (_files.isEmpty) {
      return const Center(child: Text('暂无导入文件，点右上角 + 导入'));
    }
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (ctx, i) {
        final f = _files[i];
        final id = f['id'] as int;
        final isDir = (f['isDir'] ?? 0) == 1;
        final isSel = _selected.contains(id);
        final tags = (f['tags'] as List?) ?? [];
        return ListTile(
          leading: Icon(isDir ? Icons.folder : _typeIcon(f['ext'])),
          title: Text(f['name'].toString()),
          subtitle: Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              for (final t in tags)
                Chip(
                  label: Text(t['name'].toString()),
                  labelStyle: const TextStyle(fontSize: 11),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          trailing: _selecting || isSel
              ? Icon(isSel ? Icons.check_circle : Icons.circle_outlined, color: isSel ? Colors.blue : Colors.grey)
              : null,
          selected: isSel,
          onLongPress: () => setState(() {
            _selecting = true;
            _toggleSelect(id);
          }),
          onTap: () {
            if (_selecting) {
              setState(() => _toggleSelect(id));
            } else {
              // 目录可进入（库内目录树），此处暂作提示
              if (isDir) _snack('库内目录导航开发中');
            }
          },
        );
      },
    );
  }

  void _toggleSelect(int id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    if (_selected.isEmpty) _selecting = false;
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
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }
}

/// 多选标签对话框
class _TagPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> tags;
  const _TagPickerDialog({required this.tags});

  @override
  State<_TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<_TagPickerDialog> {
  final Set<int> _chosen = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择要添加的标签'),
      content: SizedBox(
        width: 300,
        child: widget.tags.isEmpty
            ? const Text('还没有自定义标签，可先新建。')
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in widget.tags)
                    FilterChip(
                      label: Text(t['name'].toString()),
                      selected: _chosen.contains(t['id']),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _chosen.add(t['id'] as int);
                        } else {
                          _chosen.remove(t['id']);
                        }
                      }),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: _chosen.isEmpty ? null : () => Navigator.pop(context, _chosen),
          child: const Text('添加'),
        ),
      ],
    );
  }
}
