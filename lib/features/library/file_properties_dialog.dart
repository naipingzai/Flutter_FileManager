import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_manager/core/native/media_ffi.dart';
import 'package:flutter_file_manager/core/services/database_service.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';

/// 文件属性对话框（design_skill 14.1，多页签）
/// 页签：基本/标签/校验和（恒显示）+ 按类型动态追加 图片/视频/音频 信息页签
class FilePropertiesDialog extends StatefulWidget {
  final Map<String, dynamic> file;
  const FilePropertiesDialog({super.key, required this.file});

  @override
  State<FilePropertiesDialog> createState() => _FilePropertiesDialogState();
}

class _FilePropertiesDialogState extends State<FilePropertiesDialog>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final MediaNative _media = MediaNative();
  late final TabController _tab;
  List<Map<String, dynamic>> _tags = [];
  Map<String, String> _hashes = {};
  Map<String, String>? _imgInfo;
  Map<String, String>? _videoInfo;
  bool _loadingMedia = true;

  String get _path => (widget.file['path'] ?? '').toString();

  bool get _isImage => _isExt({'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'tiff', 'ico'});
  bool get _isVideo => _isExt({'mp4', 'mkv', 'mov', 'webm', 'avi', 'flv', '3gp', 'm4v'});
  bool get _isAudio => _isExt({'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'opus'});

  bool _isExt(Set<String> exts) {
    final e = ((widget.file['ext'] ?? '') as String).toLowerCase();
    return exts.contains(e);
  }

  @override
  void initState() {
    super.initState();
    _tags = _db.fileTags(widget.file['id'] as int);
    _computeHashes();
    // 基础页签：基本/标签/校验和
    int extra = 0;
    if (_isImage) extra++;
    if (_isVideo) extra++;
    if (_isAudio) extra++;
    _tab = TabController(length: 3 + extra, vsync: this);
    if (extra > 0) _loadMediaInfo();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _computeHashes() async {
    final path = _path;
    if (path.isEmpty) return;
    final hash = FileService().computeHash(path);
    if (hash == null || !mounted) return;
    setState(() {
      _hashes = {
        'MD5': hash.md5,
        'SHA-1': hash.sha1,
        'SHA-256': hash.sha256,
        'SHA-512': hash.sha512,
        'CRC32': hash.crc32,
      };
    });
  }

  Future<void> _loadMediaInfo() async {
    try {
      if (_isImage) {
        final img = FileService().decodeImage(_path);
        if (img != null && mounted) {
          _imgInfo = {
            '尺寸': '${img.width} × ${img.height} px',
          };
        }
      }
      if (_isVideo) {
        final h = _media.openVideo(_path);
        if (h != null) {
          final info = _media.getVideoInfo(h);
          _media.closeVideo(h);
          if (info != null && mounted) {
            _videoInfo = {
              '尺寸': '${info['width']} × ${info['height']} px',
              '时长': '${(info['duration'] ?? 0).toStringAsFixed(2)} s',
              '帧率': '${(info['fps'] ?? 0).toStringAsFixed(1)} fps',
            };
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingMedia = false);
  }

  String _size(dynamic v) {
    final n = (v is int) ? v : (v?.toInt() ?? 0);
    if (n < 1024) return '$n B';
    if (n < 1048576) return '${(n / 1024).toStringAsFixed(1)} KB';
    if (n < 1073741824) return '${(n / 1048576).toStringAsFixed(1)} MB';
    return '${(n / 1073741824).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final baseTabs = const [Tab(text: '基本'), Tab(text: '标签'), Tab(text: '校验和')];
    final extraTabs = <Widget>[
      if (_isImage) const Tab(text: '图片'),
      if (_isVideo) const Tab(text: '视频'),
      if (_isAudio) const Tab(text: '音频'),
    ];
    final views = <Widget>[
      _basicTab(f),
      _tagsTab(),
      _hashTab(),
      if (_isImage) _mediaInfoTab(_imgInfo),
      if (_isVideo) _mediaInfoTab(_videoInfo),
      if (_isAudio) _mediaInfoTab(null, audio: true),
    ];
    return Dialog(
      child: SizedBox(
        width: 380,
        height: 480,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                f['name'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TabBar(
              controller: _tab,
              tabs: [...baseTabs, ...extraTabs],
            ),
            Expanded(
              child: TabBarView(controller: _tab, children: views),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(k,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _basicTab(Map<String, dynamic> f) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _row('名称', f['name'].toString()),
        _row('大小', _size(f['size'])),
        _row('类型', (f['ext'] ?? '').toString().isEmpty ? '未知' : (f['ext'] ?? '').toString()),
        _row('导入时间', _fmtTime(f['importTime'])),
        _row('库路径', _path),
      ],
    );
  }

  Widget _tagsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_tags.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('暂无标签'),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _tags)
                Chip(
                  avatar: t['color'] != null
                      ? CircleAvatar(radius: 5, backgroundColor: _colorOf(t['color']))
                      : null,
                  label: Text(t['name'].toString()),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: _editTags,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('编辑标签'),
          ),
        ),
      ],
    );
  }

  Future<void> _editTags() async {
    final fileId = widget.file['id'] as int;
    final allTags = _db.tags();
    final current = _tags.map((t) => t['id'] as int).toSet();
    final chosen = <int>{
      for (final t in allTags)
        if (current.contains(t['id'])) t['id'] as int,
    };
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('编辑标签'),
          content: SizedBox(
            width: 300,
            child: allTags.isEmpty
                ? const Text('暂无标签，可先在标签管理新建。')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in allTags)
                        FilterChip(
                          label: Text(t['name'].toString()),
                          selected: chosen.contains(t['id']),
                          onSelected: (sel) {
                            setDlg(() {
                              if (sel) {
                                chosen.add(t['id'] as int);
                              } else {
                                chosen.remove(t['id']);
                              }
                            });
                          },
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, chosen),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    for (final t in _tags) {
      if (!result.contains(t['id'])) {
        _db.removeTagFromFile(fileId, t['id'] as int);
      }
    }
    for (final id in result) {
      if (!current.contains(id)) {
        _db.addTagsToFiles([fileId], [id]);
      }
    }
    setState(() => _tags = _db.fileTags(fileId));
  }

  Widget _hashTab() {
    if (_hashes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in _hashes.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(e.key,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                Expanded(
                  child: Text(
                    e.value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: '复制',
                  onPressed: () => Clipboard.setData(ClipboardData(text: e.value)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _mediaInfoTab(Map<String, String>? info, {bool audio = false}) {
    if (_loadingMedia) {
      return const Center(child: CircularProgressIndicator());
    }
    if (info == null || info.isEmpty) {
      return const Center(child: Text('无可用信息'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (audio)
          _row('时长', '音频时长请用播放器查看')
        else
          for (final e in info.entries) _row(e.key, e.value),
      ],
    );
  }

  String _fmtTime(dynamic t) {
    if (t is! int || t <= 0) return '未知';
    final d = DateTime.fromMillisecondsSinceEpoch(t * 1000);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color? _colorOf(dynamic c) {
    if (c == null) return null;
    final s = c.toString().replaceFirst('#', '');
    if (s.length != 8) return null;
    return Color(int.parse(s, radix: 16));
  }
}
