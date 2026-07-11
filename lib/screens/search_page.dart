import 'package:flutter/material.dart';
import '../services/file_service.dart';
import '../providers/file_manager_state.dart';

class SearchPage extends StatefulWidget {
  final FileManagerState state;
  const SearchPage({super.key, required this.state});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _patternController = TextEditingController(text: '*');
  final _dirController = TextEditingController();
  List<FileEntry> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _dirController.text = widget.state.currentTab.currentPath;
  }

  void _doSearch() {
    setState(() => _searching = true);
    try {
      final results = widget.state.searchFiles(_dirController.text, _patternController.text);
      setState(() { _results = results; _searching = false; });
    } catch (e) {
      setState(() { _results = []; _searching = false; });
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
            child: Column(
              children: [
                TextField(
                  controller: _patternController,
                  decoration: const InputDecoration(
                    labelText: '搜索模式 (glob, 如 *.txt)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pattern),
                  ),
                  onSubmitted: (_) => _doSearch(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dirController,
                  decoration: const InputDecoration(
                    labelText: '搜索目录',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.folder),
                  ),
                  onSubmitted: (_) => _doSearch(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _searching ? null : _doSearch,
                    icon: _searching
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    label: const Text('搜索'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _results.isEmpty
                ? Center(child: Text(_searching ? '搜索中...' : '输入搜索模式并点击搜索', style: const TextStyle(color: Colors.grey)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('找到 ${_results.length} 个结果', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final e = _results[i];
                            return ListTile(
                              leading: Icon(e.isDirectory ? Icons.folder : Icons.insert_drive_file, size: 28),
                              title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(e.path, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                              trailing: Text(e.sizeFormatted, style: const TextStyle(fontSize: 12)),
                              onTap: () {
                                if (e.isDirectory) {
                                  Navigator.pop(context);
                                  widget.state.navigateTo(e.path);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
