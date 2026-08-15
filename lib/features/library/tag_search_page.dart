import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/database_service.dart';

/// 标签搜索页（design_skill 11，模式 F）
/// 顶部：搜索框（"搜索文件名或标签"）+ 一排横向滚动的标签筛选片（可多选）
/// 下方：过滤结果列表（复用文件行布局）
class TagSearchPage extends StatefulWidget {
  const TagSearchPage({super.key});

  @override
  State<TagSearchPage> createState() => _TagSearchPageState();
}

class _TagSearchPageState extends State<TagSearchPage> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _ctrl = TextEditingController();
  final Set<int> _selectedTags = {};
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _tags = _db.tags();
    _run();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _run() {
    final q = _ctrl.text.trim();
    var files = q.isEmpty ? _db.listAll() : _db.search(q);
    if (_selectedTags.isNotEmpty) {
      files = files.where((f) {
        final ids = ((f['tags'] as List?) ?? const [])
            .map((t) => t['id'])
            .toSet();
        return _selectedTags.every(ids.contains);
      }).toList();
    }
    files.sort((a, b) => ((b['importTime'] ?? 0) as int)
        .compareTo((a['importTime'] ?? 0) as int));
    setState(() => _results = files);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索文件名或标签',
            border: InputBorder.none,
          ),
          onChanged: (_) => _run(),
        ),
        actions: [
          if (_selectedTags.isNotEmpty || _ctrl.text.trim().isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _ctrl.clear();
                _selectedTags.clear();
                _run();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 一排横向滚动的标签筛选片（可多选）
          SizedBox(
            height: 56,
            child: _tags.isEmpty
                ? const Center(child: Text('暂无标签'))
                : ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final t in _tags)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                          child: FilterChip(
                            label: Text(t['name'].toString()),
                            selected: _selectedTags.contains(t['id']),
                            avatar: t['color'] != null
                                ? CircleAvatar(
                                    radius: 5,
                                    backgroundColor: _colorOf(t['color']),
                                  )
                                : null,
                            onSelected: (sel) {
                              setState(() {
                                if (sel) {
                                  _selectedTags.add(t['id'] as int);
                                } else {
                                  _selectedTags.remove(t['id']);
                                }
                              });
                              _run();
                            },
                          ),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      '未找到匹配文件',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _results.length,
                    itemBuilder: (ctx, i) => _row(_results[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Color? _colorOf(dynamic c) {
    if (c == null) return null;
    final s = c.toString().replaceFirst('#', '');
    if (s.length != 8) return null;
    return Color(int.parse(s, radix: 16));
  }

  Widget _row(Map<String, dynamic> f) {
    final isDir = (f['isDir'] ?? 0) == 1;
    final tags = (f['tags'] as List?) ?? const [];
    return ListTile(
      leading: Icon(
        isDir ? Icons.folder : _typeIcon(f['ext']),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        f['name'].toString(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: tags.isEmpty
          ? null
          : Wrap(
              spacing: 4,
              children: [
                for (final t in tags)
                  Text(
                    '#${t['name']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
              ],
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openFile(f),
    );
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

  void _openFile(Map<String, dynamic> f) {
    // 目前仅展示；预览查看器在 LibraryPage 中实现，这里占位提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('打开文件（查看器待接）')),
    );
  }
}
