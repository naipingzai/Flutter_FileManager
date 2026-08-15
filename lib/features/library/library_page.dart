import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/native/media_ffi.dart';
import 'package:flutter_file_manager/core/services/database_service.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';
import 'package:flutter_file_manager/core/services/settings_service.dart';
import 'package:flutter_file_manager/features/viewer/audio/audio_player_page.dart';
import 'package:flutter_file_manager/features/viewer/csv/csv_viewer_page.dart';
import 'package:flutter_file_manager/features/viewer/ebook/ebook_viewer_page.dart';
import 'package:flutter_file_manager/features/viewer/image/image_viewer_page.dart';
import 'package:flutter_file_manager/features/viewer/pdf/pdf_viewer_page.dart';
import 'package:flutter_file_manager/features/viewer/text/text_editor_page.dart';
import 'package:flutter_file_manager/features/viewer/video/video_player_page.dart';

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
  int? _activeTagId; // 标签页当前选中查看的标签

  // 库内目录导航
  int _currentParent = 0; // 0=根目录
  final List<({int id, String name})> _pathStack = [];

  final Set<int> _selected = {};
  bool _selecting = false;
  bool _searching = false;
  bool _grid = false;
  _SortMode _sort = _SortMode.name;
  final TextEditingController _searchCtrl = TextEditingController();

  // 移动端布局：底部导航页
  int _navIndex = 0; // 0=文件 1=标签 2=更多
  int _gridColumns = 0; // 0=自适应；>0=固定列数（设置可配）

  @override
  void initState() {
    super.initState();
    _loadGridColumns();
    _load();
  }

  Future<void> _loadGridColumns() async {
    final c = await Settings().getGridColumns();
    if (mounted) setState(() => _gridColumns = c);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _tags = _db.tagCounts().isEmpty ? _db.tags() : _db.tagCounts();
      final q = _searchCtrl.text.trim();
      if (_navIndex == 1 && _activeTagId != null) {
        // 标签页内显示该标签下的文件
        _files = _db.filesByTag(_activeTagId!);
      } else if (_searching && q.isNotEmpty) {
        _files = _db.search(q);
      } else {
        _files = _db.listFiles(_currentParent);
      }
      _sortFiles();
    });
  }

  void _sortFiles() {
    _files.sort((a, b) {
      switch (_sort) {
        case _SortMode.size:
          return ((b['size'] ?? 0) as int).compareTo((a['size'] ?? 0) as int);
        case _SortMode.time:
          return ((b['importTime'] ?? 0) as int).compareTo((a['importTime'] ?? 0) as int);
        case _SortMode.name:
          return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
      }
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- 导入 ----------
  Future<void> _import() async {
    const typeGroup = XTypeGroup(label: '任意文件', extensions: []);
    final files = await openFiles(acceptedTypeGroups: const [typeGroup]);
    if (files.isEmpty) return;
    int ok = 0;
    for (final f in files) {
      final src = f.path;
      if (src.isEmpty) continue;
      if (_db.importFile(src) != null) ok++;
    }
    _snack('导入完成：$ok/${files.length}');
    _load();
  }

  // ---------- 新建目录 ----------
  Future<void> _mkdir() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建目录'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '目录名'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('创建')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      _db.mkdir(name, _currentParent);
      _load();
    }
  }

  // ---------- 标签 ----------
  Future<void> _createTag() async {
    final ctrl = TextEditingController();
    final colorCtr = ValueNotifier<String>('');
    final colors = [
      Colors.red, Colors.orange, Colors.amber, Colors.green,
      Colors.teal, Colors.blue, Colors.indigo, Colors.purple, Colors.pink, Colors.brown,
    ];
    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('新建标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: '标签名'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in colors)
                    InkWell(
                      onTap: () {
                        colorCtr.value = c.toARGB32().toRadixString(16).padLeft(8, '0');
                        setDlg(() {});
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: colorCtr.value == c.toARGB32().toRadixString(16).padLeft(8, '0')
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
              onPressed: () => Navigator.pop(ctx, (ctrl.text.trim(), colorCtr.value)),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    if (result != null && result.$1.isNotEmpty) {
      _db.createTag(result.$1, result.$2);
      _load();
    }
  }

  Future<void> _deleteTag(Map<String, dynamic> tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确定删除标签「${tag['name']}」？会从所有文件移除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      _db.deleteTag(tag['id'] as int);
      if (_activeTagId == tag['id']) setState(() => _activeTagId = null);
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

  Future<void> _removeTagsFromSelected() async {
    if (_selected.isEmpty) return;
    final selected = _selected.toList();
    // 取选中文件共同的标签
    final common = _db.fileTags(selected.first).map((t) => t['id'] as int).toSet();
    for (final id in selected.skip(1)) {
      final t = _db.fileTags(id).map((t) => t['id'] as int).toSet();
      common.retainAll(t);
    }
    final allTags = _db.tags();
    final chosen = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _TagPickerDialog(tags: allTags, preselected: common),
    );
    if (chosen != null && chosen.isNotEmpty) {
      for (final id in selected) {
        for (final tid in chosen) {
          _db.removeTagFromFile(id, tid);
        }
      }
      _snack('已从 ${selected.length} 个文件移除标签');
      setState(() => _selected.clear());
      _load();
    }
  }

  // ---------- 文件操作 ----------
  Future<void> _renameFile(int id, String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      _db.rename(id, name);
      _load();
    }
  }

  Future<void> _deleteFiles(List<int> ids) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除'),
        content: Text('从库中删除 ${ids.length} 项？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      for (final id in ids) {
        _db.delete(id);
      }
      setState(() => _selected.clear());
      _load();
    }
  }

  Future<void> _moveToFolder(List<int> ids) async {
    // 收集库内目录作为目标
    final dirs = _db.listAll().where((f) => (f['isDir'] ?? 0) == 1).toList();
    final target = await showDialog<int?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('移动到文件夹'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const Text('根目录'),
          ),
          for (final d in dirs)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d['id'] as int),
              child: Text(d['name'].toString()),
            ),
        ],
      ),
    );
    if (target != null) {
      for (final id in ids) {
        _db.move(id, target);
      }
      setState(() => _selected.clear());
      _load();
    }
  }

  /// 导出文件到系统选定位置
  Future<void> _exportFiles(List<int> ids) async {
    final names = ids.map((id) {
      final f = _db.listAll().where((e) => e['id'] == id).firstOrNull;
      return f?['name']?.toString() ?? 'file';
    }).toList();
    for (var i = 0; i < ids.length; i++) {
      final dest = await getSaveLocation(suggestedName: names[i]);
      if (dest == null) return;
      final err = _db.exportFile(ids[i], dest.path);
      if (err != null) _snack('导出失败: $err');
    }
    if (ids.length > 1) _snack('已导出 ${ids.length} 个文件');
    setState(() => _selected.clear());
  }

  // ---------- 目录导航 ----------
  void _enterDir(Map<String, dynamic> dir) {
    setState(() {
      _pathStack.add((id: dir['id'] as int, name: dir['name'].toString()));
      _currentParent = dir['id'] as int;
      _activeTagId = null;
    });
    _load();
  }

  void _goBack() {
    if (_pathStack.isEmpty) return;
    setState(() {
      _pathStack.removeLast();
      _currentParent = _pathStack.isEmpty ? 0 : _pathStack.last.id;
    });
    _load();
  }

  /// 退出标签页的文件查看，回到标签列表
  void _exitTagView() {
    setState(() => _activeTagId = null);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索库内文件...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => _load(),
              )
            : Text(_navIndex == 0
                ? _currentPathText
                : _navIndex == 1
                    ? (_activeTagId != null ? '标签: ${_tagName(_activeTagId)}' : '标签')
                    : '更多'),
        leading: _navIndex == 0
            ? (_searching
                ? IconButton(icon: const Icon(Icons.close), onPressed: () {
                    setState(() {
                      _searching = false;
                      _searchCtrl.clear();
                    });
                    _load();
                  })
                : (_pathStack.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
                    : null))
            : (_navIndex == 1 && _activeTagId != null
                ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _exitTagView)
                : null),
        actions: [
          if (_navIndex == 0) ...[
            IconButton(
              icon: Icon(_searching ? Icons.search_off : Icons.search),
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchCtrl.clear();
                  _load();
                }
              }),
            ),
            IconButton(
              icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
              tooltip: _grid ? '列表视图' : '网格视图',
              onPressed: () => setState(() => _grid = !_grid),
            ),
            PopupMenuButton<_SortMode>(
              icon: const Icon(Icons.sort),
              tooltip: '排序',
              onSelected: (m) => setState(() {
                _sort = m;
                _sortFiles();
              }),
              itemBuilder: (_) => const [
                CheckedPopupMenuItem(value: _SortMode.name, child: Text('按名称')),
                CheckedPopupMenuItem(value: _SortMode.size, child: Text('按大小')),
                CheckedPopupMenuItem(value: _SortMode.time, child: Text('按导入时间')),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.add),
              tooltip: '导入',
              onSelected: (v) {
                if (v == 'file') _import();
                if (v == 'dir') _importDir();
                if (v == 'mkdir') _mkdir();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'file', child: Text('导入文件')),
                PopupMenuItem(value: 'dir', child: Text('导入文件夹')),
                PopupMenuItem(value: 'mkdir', child: Text('新建目录')),
              ],
            ),
          ],
          if (_navIndex == 1) ...[
            if (_activeTagId != null)
              IconButton(
                icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
                tooltip: _grid ? '列表视图' : '网格视图',
                onPressed: () => setState(() => _grid = !_grid),
              ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '新建标签',
              onPressed: _createTag,
            ),
          ],
        ],
      ),
      body: IndexedStack(
        index: _navIndex,
        children: [
          _buildLibraryTab(),
          _buildTagsTab(),
          _buildMoreTab(),
        ],
      ),
      bottomNavigationBar: _selecting
          ? _buildSelectionBar()
          : _buildBottomNav(),
    );
  }

  /// M3 悬浮底栏：圆角胶囊浮于内容之上，药丸形选中指示器 + 导航项。
  Widget _buildBottomNav() {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          elevation: 6,
          shadowColor: cs.shadow,
          color: cs.surfaceContainer,
          surfaceTintColor: cs.surfaceTint,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navDest(0, Icons.folder_outlined, Icons.folder, '文件'),
                _navDest(1, Icons.label_outline, Icons.label, '标签'),
                _navDest(2, Icons.more_horiz, Icons.more_horiz, '更多'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// M3 导航目的地（药丸形选中指示器）
  Widget _navDest(int i, IconData icon, IconData selIcon, String label) {
    final cs = Theme.of(context).colorScheme;
    final sel = _navIndex == i;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() => _navIndex = i);
        _load();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? cs.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              sel ? selIcon : icon,
              color: sel ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
              color: sel ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryTab() {
    // 主页 = 目录结构：面包屑 + 文件列表（不显示标签/类型分类）
    return Column(
      children: [
        _buildBreadcrumb(),
        const SizedBox(height: 4),
        Expanded(child: _buildFileList()),
      ],
    );
  }

  /// 面包屑路径导航（参考 AdvanceFileManager）
  Widget _buildBreadcrumb() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _crumb('文件', () {
            setState(() {
              _pathStack.clear();
              _currentParent = 0;
            });
            _load();
          }),
          for (var i = 0; i < _pathStack.length; i++)
            _crumb(_pathStack[i].name, () {
              setState(() {
                _pathStack.removeRange(i + 1, _pathStack.length);
                _currentParent = _pathStack[i].id;
              });
              _load();
            }),
        ],
      ),
    );
  }

  Widget _crumb(String name, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Align(
        alignment: Alignment.center,
        child: ActionChip(
          avatar: const Icon(Icons.chevron_right, size: 16),
          label: Text(name, style: const TextStyle(fontSize: 12)),
          onPressed: onTap,
        ),
      ),
    );
  }

  /// 标签页：进入显示全部标签列表；点标签在标签页内显示该标签下的文件（可返回）
  Widget _buildTagsTab() {
    if (_activeTagId != null) {
      // 在标签页内直接展示该标签的文件，右上角有返回
      return _buildFileList();
    }
    final tags = _tags;
    if (tags.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.label_outline, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('还没有标签', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _createTag,
              icon: const Icon(Icons.add),
              label: const Text('新建标签'),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final t in tags)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(radius: 6, backgroundColor: _colorOf(t['color']) ?? Theme.of(context).colorScheme.onSurfaceVariant),
              title: Text(t['name'].toString()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${t['count'] ?? 0} 个', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  IconButton(icon: const Icon(Icons.more_vert, size: 18), onPressed: () => _tagMenu(t)),
                ],
              ),
              onTap: () {
                setState(() => _activeTagId = t['id'] as int);
                _load();
              },
            ),
          ),
      ],
    );
  }

  /// 更多页：导入入口 + 说明
  Widget _buildMoreTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _moreCard(Icons.add, '导入文件', '从系统选择文件导入到文件库', _import),
        _moreCard(Icons.create_new_folder, '导入文件夹', '递归导入整个文件夹', _importDir),
        _moreCard(Icons.folder_special, '新建目录', '在文件库内新建目录', _mkdir),
        _moreCard(Icons.bar_chart, '库统计', '查看文件数/大小/类型统计', _showDashboard),
        _buildGridSettingCard(),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '导入式文件管理 · 数据库 + 标签系统',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _moreCard(IconData icon, String title, String sub, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildGridSettingCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.grid_view, color: Theme.of(context).colorScheme.primary),
        title: const Text('网格视图列数', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          _gridColumns == 0 ? '自动（按宽度）' : '固定 $_gridColumns 列',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pickGridColumns(),
      ),
    );
  }

  Future<void> _pickGridColumns() async {
    final sel = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('网格视图列数'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const Text('自动（按宽度）'),
          ),
          for (var i = 1; i <= 6; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: Text('$i 列'),
            ),
        ],
      ),
    );
    if (sel != null) {
      await Settings().setGridColumns(sel);
      if (mounted) setState(() => _gridColumns = sel);
    }
  }

  String get _currentPathText {
    if (_pathStack.isEmpty) return '文件';
    return _pathStack.map((e) => e.name).join('/');
  }

  String _tagName(int? id) {
    if (id == null) return '';
    for (final t in _tags) {
      if (t['id'] == id) return t['name'].toString();
    }
    return '?';
  }

  Future<void> _tagMenu(Map<String, dynamic> tag) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名标签'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除标签'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename') {
      await _renameTag(tag);
    } else if (action == 'delete') {
      await _deleteTag(tag);
    }
  }

  Future<void> _renameTag(Map<String, dynamic> tag) async {
    final ctrl = TextEditingController(text: tag['name'].toString());
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名标签'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      _db.renameTag(tag['id'] as int, name);
      _load();
    }
  }

  Widget _buildFileList() {
    if (_files.isEmpty) {
      if (_activeTagId != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.label_off_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              const Text('该标签下暂无文件'),
              TextButton(
                onPressed: _exitTagView,
                child: const Text('返回标签列表'),
              ),
            ],
          ),
        );
      }
      return const Center(child: Text('暂无内容，点右上角导入或新建目录'));
    }
    if (_grid) {
      // 网格列数：设置里可配固定列数，否则按宽度自适应（每格约 120dp）
      final crossCount = _gridColumns > 0
          ? _gridColumns
          : (MediaQuery.of(context).size.width / 120).floor().clamp(2, 8);
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: _files.length,
        itemBuilder: (ctx, i) => _buildGridTile(_files[i]),
      );
    }
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (ctx, i) => _buildListTile(_files[i]),
    );
  }

  Widget _buildListTile(Map<String, dynamic> f) {
    final id = f['id'] as int;
    final isDir = (f['isDir'] ?? 0) == 1;
    final isSel = _selected.contains(id);
    final subtitle = (f['size'] ?? 0) > 0
        ? Text(_size(f['size']), style: const TextStyle(fontSize: 12))
        : null;
    final trailing = _selecting || isSel
        ? Icon(isSel ? Icons.check_circle : Icons.circle_outlined,
            color: isSel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)
        : (!isDir
            ? IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _onFileMenu(f),
              )
            : null);

    // 左侧：图片预览图 / 视频封面（方框），其余为类型图标
    Widget leading;
    if (isDir) {
      leading = Icon(Icons.folder, size: 36, color: Theme.of(context).colorScheme.onSurfaceVariant);
    } else if (_isImage(f['ext'])) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 48,
          height: 44,
          child: ThumbnailImage(path: (f['path'] ?? '').toString()),
        ),
      );
    } else if (_isVideo(f['ext'])) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 48,
          height: 44,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ThumbnailImage(path: (f['path'] ?? '').toString(), isVideo: true),
              const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 20)),
            ],
          ),
        ),
      );
    } else {
      leading = Icon(_typeIcon(f['ext']), size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: isSel ? Theme.of(context).colorScheme.primaryContainer : null,
        child: InkWell(
          onTap: () => _onTileTap(f, isDir, id),
          onLongPress: () => setState(() {
            _selecting = true;
            _toggleSelect(id);
          }),
          // 统一行高 64，内容上下左右居中
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Center(child: SizedBox(width: 48, height: 48, child: Center(child: leading))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f['name'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        subtitle,
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Center(child: trailing ?? const SizedBox(width: 48, height: 24)),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridTile(Map<String, dynamic> f) {
    final id = f['id'] as int;
    final isDir = (f['isDir'] ?? 0) == 1;
    final isSel = _selected.contains(id);
    return GestureDetector(
      onLongPress: () => setState(() {
        _selecting = true;
        _toggleSelect(id);
      }),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onTileTap(f, isDir, id),
          // 百分比布局：预览图 ~60%，名称 ~25%，大小 ~15%，比例协调，避免"大格子小内容"
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Expanded(
                  flex: 60,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: _isImage(f['ext'])
                            ? ThumbnailImage(path: (f['path'] ?? '').toString())
                            : _isVideo(f['ext'])
                                ? ThumbnailImage(path: (f['path'] ?? '').toString(), isVideo: true)
                                : Icon(isDir ? Icons.folder : _typeIcon(f['ext']),
                                    size: 34, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      if (isSel)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  flex: 25,
                  child: Center(
                    child: Text(
                      f['name'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                Expanded(
                  flex: 15,
                  child: Center(
                    child: Text(
                      (f['size'] ?? 0) > 0 ? _size(f['size']) : '',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTileTap(Map<String, dynamic> f, bool isDir, int id) {
    if (_selecting) {
      setState(() => _toggleSelect(id));
    } else if (isDir) {
      _enterDir(f);
    } else {
      _preview(f);
    }
  }

  void _onFileMenu(Map<String, dynamic> f) {
    final id = f['id'] as int;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('预览'),
              onTap: () {
                Navigator.pop(ctx);
                _preview(f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sell_outlined),
              title: const Text('添加标签'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _selecting = true;
                  _selected.add(id);
                });
                _addTagsToSelected();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('导出'),
              onTap: () {
                Navigator.pop(ctx);
                _exportFiles([id]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: const Text('移动到文件夹'),
              onTap: () {
                Navigator.pop(ctx);
                _moveToFolder([id]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _renameFile(id, f['name'].toString());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteFiles([id]);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 用内部路径打开对应查看器
  void _preview(Map<String, dynamic> f) {
    final path = (f['path'] ?? '').toString();
    if (path.isEmpty) return;
    final type = FileService().determineViewer(path);
    Widget page;
    switch (type) {
      case FileViewerType.image:
        page = ImageViewerPage(initialPath: path);
        break;
      case FileViewerType.video:
        page = VideoPlayerPage(path: path);
        break;
      case FileViewerType.audio:
        page = AudioPlayerPage(path: path);
        break;
      case FileViewerType.pdf:
        page = PdfViewerPage(path: path);
        break;
      case FileViewerType.ebook:
        page = EbookViewerPage(path: path);
        break;
      case FileViewerType.csv:
        page = CsvViewerPage(path: path);
        break;
      case FileViewerType.text:
        page = TextEditorPage(path: path);
        break;
      default:
        _snack('无法预览该类型: ${f['name']}');
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildSelectionBar() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${_selected.length} 已选'),
            ),
            IconButton(icon: const Icon(Icons.sell_outlined), tooltip: '加标签', onPressed: _addTagsToSelected),
            IconButton(icon: const Icon(Icons.sell), tooltip: '移除标签', onPressed: _removeTagsFromSelected),
            IconButton(icon: const Icon(Icons.drive_file_move_outlined), tooltip: '移动', onPressed: () => _moveToFolder(_selected.toList())),
            IconButton(icon: const Icon(Icons.upload_outlined), tooltip: '导出', onPressed: () => _exportFiles(_selected.toList())),
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: '删除', onPressed: () => _deleteFiles(_selected.toList())),
            IconButton(icon: const Icon(Icons.close), tooltip: '取消', onPressed: () => setState(() {
              _selecting = false;
              _selected.clear();
            })),
          ],
        ),
      ),
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

  bool _isImage(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
      case 'bmp':
      case 'tiff':
      case 'ico':
        return true;
      default:
        return false;
    }
  }

  bool _isVideo(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'mp4':
      case 'mkv':
      case 'mov':
      case 'webm':
      case 'avi':
      case 'flv':
      case '3gp':
        return true;
      default:
        return false;
    }
  }

  // 批量导入文件夹（递归）
  Future<void> _importDir() async {
    final dir = await getDirectoryPath();
    if (dir == null || dir.isEmpty) return;
    final result = _db.importDir(dir);
    if (result == null) {
      _snack('导入失败');
    } else {
      _snack('导入完成：成功 ${result.imported}，失败 ${result.failed}');
    }
    _load();
  }

  // 库内统计/仪表盘
  Future<void> _showDashboard() async {
    final stats = _db.stats();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('库统计'),
        content: _DashboardContent(stats: stats),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  Color? _colorOf(dynamic color) {
    if (color == null || color.toString().isEmpty) return null;
    try {
      final value = int.parse(color.toString(), radix: 16);
      return Color(value);
    } catch (_) {
      return null;
    }
  }

  String _size(dynamic v) {
    final n = (v is int) ? v : (v?.toInt() ?? 0);
    if (n < 1024) return '$n B';
    if (n < 1048576) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / 1048576).toStringAsFixed(1)} MB';
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
  final Set<int> preselected;
  const _TagPickerDialog({required this.tags, this.preselected = const {}});

  @override
  State<_TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<_TagPickerDialog> {
  late final Set<int> _chosen = {...widget.preselected};

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

/// 图片/视频缩略图：原生解码缩放后异步显示（加载中/失败显示占位）
class ThumbnailImage extends StatefulWidget {
  final String path;
  final bool isVideo;
  final double maxSize;
  const ThumbnailImage({super.key, required this.path, this.isVideo = false, this.maxSize = 256});

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  ui.Image? _image;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.path.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final j = widget.isVideo
        ? MediaNative().makeVideoThumbnailJson(widget.path, widget.maxSize.round())
        : MediaNative().makeThumbnailJson(widget.path, widget.maxSize.round());
    if (!mounted) return;
    if (j == null || (j['error'] as String? ?? '').isNotEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final bytes = base64Decode(j['base64'] as String? ?? '');
      final w = (j['width'] as int?) ?? 0;
      final h = (j['height'] as int?) ?? 0;
      if (bytes.isEmpty || w <= 0 || h <= 0) {
        setState(() => _loading = false);
        return;
      }
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(bytes, w, h, ui.PixelFormat.rgba8888, completer.complete);
      final img = await completer.future;
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() {
        _image = img;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_image == null) {
      return Center(child: Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 28));
    }
    return RawImage(image: _image, fit: BoxFit.cover);
  }
}

enum _SortMode { name, size, time }

/// 库统计内容
class _DashboardContent extends StatelessWidget {
  final Map<String, dynamic>? stats;
  const _DashboardContent({this.stats});

  String _size(dynamic v) {
    final n = (v is int) ? v : (v?.toInt() ?? 0);
    if (n < 1024) return '$n B';
    if (n < 1048576) return '${(n / 1024).toStringAsFixed(1)} KB';
    if (n < 1073741824) return '${(n / 1048576).toStringAsFixed(1)} MB';
    return '${(n / 1073741824).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const Text('暂无数据');
    final s = stats!;
    final byType = (s['byType'] as Map?) ?? {};
    final byTag = (s['byTag'] as List?) ?? [];
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(k), Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        );
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row('文件数', '${s['files'] ?? 0}'),
          row('目录数', '${s['dirs'] ?? 0}'),
          row('总大小', _size(s['size'])),
          const Divider(),
          const Text('按类型', style: TextStyle(fontWeight: FontWeight.bold)),
          row('图片', '${byType['image'] ?? 0}'),
          row('视频', '${byType['video'] ?? 0}'),
          row('音频', '${byType['audio'] ?? 0}'),
          row('文档', '${byType['doc'] ?? 0}'),
          row('其他', '${byType['other'] ?? 0}'),
          if (byTag.isNotEmpty) ...[
            const Divider(),
            const Text('按标签', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final t in byTag)
              row((t['name'] ?? '').toString(), '${t['count'] ?? 0}'),
          ],
        ],
      ),
    );
  }
}
