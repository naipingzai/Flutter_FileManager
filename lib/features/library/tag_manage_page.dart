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

  // 标签可选颜色：从 colorScheme 派生（深浅色主题自适应），而非硬编码 Colors.*
  List<Color> _colorOptions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return [
      cs.primary,
      cs.secondary,
      cs.tertiary,
      cs.error,
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiaryContainer,
      cs.errorContainer,
    ];
  }

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
    final cs = Theme.of(context).colorScheme;
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
                      size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('暂无标签，点击右上角新建',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final t in _tags)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 7,
                      backgroundColor:
                          _colorOf(t['color']) ?? cs.onSurfaceVariant,
                    ),
                    title: Text(t['name'].toString()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${t['count'] ?? 0} 个',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                        IconButton(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onPressed: () => _tagMenu(t),
                        ),
                      ],
                    ),
                    onTap: () => _editTag(t),
                  ),
              ],
            ),
    );
  }

  Widget _colorPicker(Color chosen, ValueChanged<Color> onSelect) {
    return Wrap(
      spacing: 8,
      children: [
        for (final c in _colorOptions(context))
          ChoiceChip(
            avatar: CircleAvatar(radius: 8, backgroundColor: c),
            label: const SizedBox.shrink(),
            selected: chosen.toARGB32() == c.toARGB32(),
            showCheckmark: false,
            onSelected: (_) => onSelect(c),
          ),
      ],
    );
  }

  Future<void> _createTag() async {
    final ctrl = TextEditingController();
    final opts = _colorOptions(context);
    Color chosen = opts.first;
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
              _colorPicker(chosen, (c) => setDlg(() => chosen = c)),
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
    final opts = _colorOptions(context);
    Color chosen = _colorOf(tag['color']) ?? opts.first;
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
              _colorPicker(chosen, (c) => setDlg(() => chosen = c)),
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