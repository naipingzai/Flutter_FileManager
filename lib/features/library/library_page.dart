import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/database_service.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';
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
  int? _filterTagId;

  // 库内目录导航
  int _currentParent = 0; // 0=根目录
  final List<({int id, String name})> _pathStack = [];

  final Set<int> _selected = {};
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _tags = _db.tags();
      _files = _filterTagId == null ? _db.listFiles(_currentParent) : _db.filesByTag(_filterTagId!);
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
                              ? Border.all(color: Colors.black, width: 2)
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
      if (_filterTagId == tag['id']) setState(() => _filterTagId = null);
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

  // ---------- 目录导航 ----------
  void _enterDir(Map<String, dynamic> dir) {
    setState(() {
      _pathStack.add((id: dir['id'] as int, name: dir['name'].toString()));
      _currentParent = dir['id'] as int;
      _filterTagId = null;
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

  void _resetToRoot() {
    setState(() {
      _pathStack.clear();
      _currentParent = 0;
      _filterTagId = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_filterTagId != null ? '标签: ${_tagName(_filterTagId)}' : _currentPathText),
        leading: _pathStack.isNotEmpty
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
            : null,
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: '导入文件', onPressed: _import),
          IconButton(icon: const Icon(Icons.create_new_folder_outlined), tooltip: '新建目录', onPressed: _mkdir),
          IconButton(icon: const Icon(Icons.new_label_outlined), tooltip: '新建标签', onPressed: _createTag),
          IconButton(icon: const Icon(Icons.home), tooltip: '根目录', onPressed: _resetToRoot),
        ],
      ),
      body: Column(
        children: [
          _buildTagBar(),
          const Divider(height: 1),
          Expanded(child: _buildFileList()),
        ],
      ),
      bottomNavigationBar: _selecting ? _buildSelectionBar() : null,
    );
  }

  String get _currentPathText {
    if (_pathStack.isEmpty) return '文件库';
    return _pathStack.map((e) => e.name).join('/');
  }

  String _tagName(int? id) {
    if (id == null) return '';
    for (final t in _tags) {
      if (t['id'] == id) return t['name'].toString();
    }
    return '?';
  }

  Widget _buildTagBar() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        children: [
          _tagChip(null, '全部', _filterTagId == null),
          for (final t in _tags) _tagChip(t['id'], t['name'], _filterTagId == t['id'], tag: t),
        ],
      ),
    );
  }

  Widget _tagChip(dynamic id, String name, bool selected, {Map<String, dynamic>? tag}) {
    final color = _colorOf(tag?['color']);
    final chip = ChoiceChip(
      avatar: color != null ? CircleAvatar(backgroundColor: color, radius: 6) : null,
      label: Text(name),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _filterTagId = id as int?;
          _currentParent = 0;
          _pathStack.clear();
        });
        _load();
      },
    );
    if (tag == null) return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: chip);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onLongPress: () => _deleteTag(tag),
        child: chip,
      ),
    );
  }

  Widget _buildFileList() {
    if (_files.isEmpty) {
      return const Center(child: Text('暂无内容，点右上角导入或新建目录'));
    }
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (ctx, i) {
        final f = _files[i];
        final id = f['id'] as int;
        final isDir = (f['isDir'] ?? 0) == 1;
        final isSel = _selected.contains(id);
        final tags = (f['tags'] as List?) ?? [];
        final title = Text(f['name'].toString());
        final subtitle = Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            if ((f['size'] ?? 0) > 0)
              Text(_size(f['size']), style: const TextStyle(fontSize: 11)),
            for (final t in tags)
              Chip(
                avatar: _colorOf(t['color']) != null
                    ? CircleAvatar(backgroundColor: _colorOf(t['color']), radius: 5)
                    : null,
                label: Text(t['name'].toString()),
                labelStyle: const TextStyle(fontSize: 11),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        );
        final leading = Icon(isDir ? Icons.folder : _typeIcon(f['ext']), size: 32);
        final trailing = _selecting || isSel
            ? Icon(isSel ? Icons.check_circle : Icons.circle_outlined,
                color: isSel ? Colors.blue : Colors.grey)
            : (!isDir
                ? IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _onFileMenu(f),
                  )
                : null);

        return ListTile(
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          selected: isSel,
          onLongPress: () => setState(() {
            _selecting = true;
            _toggleSelect(id);
          }),
          onTap: () {
            if (_selecting) {
              setState(() => _toggleSelect(id));
            } else if (isDir) {
              _enterDir(f);
            } else {
              _preview(f);
            }
          },
        );
      },
    );
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
            IconButton(icon: const Icon(Icons.drive_file_move_outlined), tooltip: '移动', onPressed: () => _moveToFolder(_selected.toList())),
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
