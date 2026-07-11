import 'package:flutter/material.dart';
import '../providers/file_manager_state.dart';
import '../services/file_service.dart';

class ToolsPage extends StatelessWidget {
  final FileManagerState state;
  const ToolsPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件工具')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _toolCard(context, Icons.search, '文件搜索', '按名称模式搜索文件', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => _SearchTool(state: state)));
          }),
          _toolCard(context, Icons.content_copy, '重复文件查找', '查找相同内容的重复文件', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => _DuplicatesTool(state: state)));
          }),
          _toolCard(context, Icons.delete_sweep, '空文件查找', '查找空文件和空目录', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => _EmptyFilesTool(state: state)));
          }),
          _toolCard(context, Icons.fingerprint, '文件校验和', '计算文件的哈希值', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => _HashTool(state: state)));
          }),
          _toolCard(context, Icons.compare, '文件对比', '逐字节比较两个文件', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => _CompareTool(state: state)));
          }),
        ],
      ),
    );
  }

  Widget _toolCard(BuildContext ctx, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SearchTool extends StatefulWidget {
  final FileManagerState state;
  const _SearchTool({required this.state});
  @override
  State<_SearchTool> createState() => _SearchToolState();
}

class _SearchToolState extends State<_SearchTool> {
  final _dirCtrl = TextEditingController();
  final _patternCtrl = TextEditingController(text: '*');
  List<FileEntry> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _dirCtrl.text = widget.state.currentTab.currentPath;
  }

  void _search() {
    setState(() => _searching = true);
    try {
      final r = widget.state.searchFiles(_dirCtrl.text, _patternCtrl.text);
      setState(() { _results = r; _searching = false; });
    } catch (e) {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(controller: _patternCtrl, decoration: const InputDecoration(labelText: '搜索模式 (glob)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _dirCtrl, decoration: const InputDecoration(labelText: '搜索目录', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _searching ? null : _search, icon: const Icon(Icons.search), label: const Text('搜索'))),
            ]),
          ),
          Expanded(child: _results.isEmpty
              ? const Center(child: Text('无结果'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final e = _results[i];
                    return ListTile(
                      leading: Icon(e.isDirectory ? Icons.folder : Icons.insert_drive_file),
                      title: Text(e.name),
                      subtitle: Text(e.path, style: const TextStyle(fontSize: 11)),
                      trailing: Text(e.sizeFormatted),
                    );
                  },
                )),
        ],
      ),
    );
  }
}

class _DuplicatesTool extends StatefulWidget {
  final FileManagerState state;
  const _DuplicatesTool({required this.state});
  @override
  State<_DuplicatesTool> createState() => _DuplicatesToolState();
}

class _DuplicatesToolState extends State<_DuplicatesTool> {
  List<FileEntry> _results = [];
  bool _searching = false;

  void _find() {
    setState(() => _searching = true);
    try {
      final r = widget.state.findDuplicates(widget.state.currentTab.currentPath);
      setState(() { _results = r; _searching = false; });
    } catch (e) {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('重复文件查找')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _searching ? null : _find,
              icon: _searching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.content_copy),
              label: const Text('查找重复文件'),
            ),
          ),
        ),
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('找到 ${_results.length} 个重复文件', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        Expanded(child: _results.isEmpty
            ? Center(child: Text(_searching ? '扫描中...' : '点击按钮开始查找', style: const TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (ctx, i) {
                  final e = _results[i];
                  return ListTile(
                    leading: Icon(Icons.copy, color: Theme.of(context).colorScheme.error),
                    title: Text(e.name),
                    subtitle: Text(e.path, style: const TextStyle(fontSize: 11)),
                    trailing: Text(e.sizeFormatted),
                  );
                },
              )),
      ]),
    );
  }
}

class _EmptyFilesTool extends StatefulWidget {
  final FileManagerState state;
  const _EmptyFilesTool({required this.state});
  @override
  State<_EmptyFilesTool> createState() => _EmptyFilesToolState();
}

class _EmptyFilesToolState extends State<_EmptyFilesTool> {
  List<FileEntry> _results = [];
  bool _searching = false;

  void _find() {
    setState(() => _searching = true);
    try {
      final r = widget.state.findEmptyFiles(widget.state.currentTab.currentPath);
      setState(() { _results = r; _searching = false; });
    } catch (e) {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('空文件查找')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _searching ? null : _find,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('查找空文件'),
            ),
          ),
        ),
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('找到 ${_results.length} 个空文件/目录', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        Expanded(child: _results.isEmpty
            ? Center(child: Text(_searching ? '扫描中...' : '点击按钮开始查找', style: const TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (ctx, i) {
                  final e = _results[i];
                  return ListTile(
                    leading: Icon(e.isDirectory ? Icons.folder_open : Icons.insert_drive_file, color: Colors.orange),
                    title: Text(e.name),
                    subtitle: Text(e.path, style: const TextStyle(fontSize: 11)),
                  );
                },
              )),
      ]),
    );
  }
}

class _HashTool extends StatefulWidget {
  final FileManagerState state;
  const _HashTool({required this.state});
  @override
  State<_HashTool> createState() => _HashToolState();
}

class _HashToolState extends State<_HashTool> {
  final _pathCtrl = TextEditingController();
  FileHash? _hash;
  bool _computing = false;

  void _compute() {
    setState(() => _computing = true);
    try {
      final h = widget.state.computeHash(_pathCtrl.text);
      setState(() { _hash = h; _computing = false; });
    } catch (e) {
      setState(() => _computing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件校验和')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _pathCtrl, decoration: const InputDecoration(labelText: '文件路径', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _computing ? null : _compute,
            icon: const Icon(Icons.fingerprint),
            label: const Text('计算校验和'),
          )),
          const SizedBox(height: 16),
          if (_hash != null)
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hashRow('MD5', _hash!.md5),
                _hashRow('SHA1', _hash!.sha1),
                _hashRow('SHA256', _hash!.sha256),
                _hashRow('SHA512', _hash!.sha512),
                _hashRow('CRC32', _hash!.crc32),
              ],
            ))),
        ]),
      ),
    );
  }

  Widget _hashRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: SelectableText(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
        ],
      ),
    );
  }
}

class _CompareTool extends StatefulWidget {
  final FileManagerState state;
  const _CompareTool({required this.state});
  @override
  State<_CompareTool> createState() => _CompareToolState();
}

class _CompareToolState extends State<_CompareTool> {
  final _path1Ctrl = TextEditingController();
  final _path2Ctrl = TextEditingController();
  String? _result;

  void _compare() {
    final h1 = widget.state.computeHash(_path1Ctrl.text);
    final h2 = widget.state.computeHash(_path2Ctrl.text);
    if (h1 == null || h2 == null) {
      setState(() => _result = '无法读取文件');
      return;
    }
    final match = h1.md5 == h2.md5;
    setState(() => _result = match ? '文件相同 (MD5 匹配)' : '文件不同');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件对比')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _path1Ctrl, decoration: const InputDecoration(labelText: '文件 1 路径', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _path2Ctrl, decoration: const InputDecoration(labelText: '文件 2 路径', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _compare, icon: const Icon(Icons.compare), label: const Text('对比'))),
          const SizedBox(height: 16),
          if (_result != null)
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(_result!.contains('相同') ? Icons.check_circle : Icons.cancel,
                    color: _result!.contains('相同') ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(_result!, style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            )),
        ]),
      ),
    );
  }
}
