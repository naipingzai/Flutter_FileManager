import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/database_service.dart';

/// 标签管理页（design_skill 10.5 / 13.3，模式 A）
/// 顶部栏 + 右上"新建标签"；每行: [标签色圆点] 标签名  文件数  [更多]
class TagManagePage extends StatefulWidget {
  const TagManagePage({super.key});

  @override
  State<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends State<TagManagePage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _tags = [];

  static const _colors = [
    Colors.red, Colors.orange, Colors.amber, Colors.green,
    Colors.teal, Colors.blue, Colors.indigo, Colors.purple,
    Colors.pink, Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final counts = _db.tagCounts();
    setState(() {
      _tags = counts.isEmpty ? _db.tags() : counts;
    });
  }

  Color? _colorOf(dynamic c) {
    if (c == null) return null;
    final s = c.toString().replaceFirst('#', '');
    if (s.length != 8) return null;
    return Color(int.parse(s, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建标签',
            onPressed: _createTag,
          ),
        ],
      ),
      body: _tags.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.label_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('暂无标签，点击右上角新建',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _createTag,
                    icon: const Icon(Icons.add),
                    label: const Text('新建标签'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final t in _tags)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 7,
                        backgroundColor:
                            _colorOf(t['color']) ??
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(t['name'].toString()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${t['count'] ?? 0} 个',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          IconButton(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onPressed: () => _tagMenu(t),
                          ),
                        ],
                      ),
                      onTap: () => _editTag(t),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _createTag() async {
    final ctrl = TextEditingController();
    Color chosen = _colors.first;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('新建标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '标签名')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in _colors)
                    InkWell(
                      onTap: () => setDlg(() => chosen = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: chosen == c
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  width: 2)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (name != null && name.isNotEmpty) {
      _db.createTag(name, _argb(chosen));
      _reload();
    }
  }

  Future<void> _editTag(Map<String, dynamic> tag) async {
    final ctrl = TextEditingController(text: tag['name'].toString());
    Color chosen = _colorOf(tag['color']) ?? _colors.first;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('编辑标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: ctrl, autofocus: true),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in _colors)
                    InkWell(
                      onTap: () => setDlg(() => chosen = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: chosen == c
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  width: 2)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (name != null && name.isNotEmpty) {
      _db.renameTag(tag['id'] as int, name);
      _db.tagColor(tag['id'] as int, _argb(chosen));
      _reload();
    }
  }

  Future<void> _tagMenu(Map<String, dynamic> tag) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('删除'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      _editTag(tag);
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除标签'),
          content: Text(
              '确定删除标签「${tag['name']}」？\n将从 ${tag['count'] ?? 0} 个文件中移除该标签。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        _db.deleteTag(tag['id'] as int);
        _reload();
      }
    }
  }

  String _argb(Color c) => c.toARGB32().toRadixString(16).padLeft(8, '0');
}
