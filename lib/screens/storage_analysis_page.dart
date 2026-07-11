import 'package:flutter/material.dart';
import '../providers/file_manager_state.dart';
import '../services/file_service.dart';
import '../utils/formatters.dart';

class StorageAnalysisPage extends StatefulWidget {
  final FileManagerState state;
  const StorageAnalysisPage({super.key, required this.state});

  @override
  State<StorageAnalysisPage> createState() => _StorageAnalysisPageState();
}

class _StorageAnalysisPageState extends State<StorageAnalysisPage> {
  DiskUsage? _diskUsage;
  List<_TypeStat> _stats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  void _analyze() {
    setState(() => _loading = true);
    try {
      final du = widget.state.getDiskUsage('/');
      final entries = widget.state.fileService.listDirectory(widget.state.currentTab.currentPath, showHidden: true);
      final Map<String, _TypeStat> statMap = {};
      for (final e in entries) {
        if (!e.isDirectory) {
          final ext = e.name.contains('.') ? '.${e.name.split('.').last.toLowerCase()}' : '(无扩展名)';
          statMap.putIfAbsent(ext, () => _TypeStat(ext, 0, 0));
          statMap[ext]!.count++;
          statMap[ext]!.totalSize += e.size;
        }
      }
      final sorted = statMap.values.toList()..sort((a, b) => b.totalSize.compareTo(a.totalSize));
      setState(() { _diskUsage = du; _stats = sorted; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('存储分析')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_diskUsage != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 120,
                            width: 120,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: _diskUsage!.percent / 100,
                                  strokeWidth: 12,
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                ),
                                Center(child: Text('${_diskUsage!.percent.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _statCol('总空间', _diskUsage!.totalFormatted, theme.colorScheme.primary),
                              _statCol('已使用', _diskUsage!.usedFormatted, theme.colorScheme.error),
                              _statCol('可用', _diskUsage!.freeFormatted, theme.colorScheme.tertiary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_stats.isNotEmpty) ...[
                  Text('按类型统计', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._stats.take(20).map((s) => Card(
                    child: ListTile(
                      title: Text(s.ext),
                      subtitle: Text('${s.count} 个文件'),
                      trailing: Text(Formatters.formatSize(s.totalSize), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )),
                ],
              ],
            ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _TypeStat {
  final String ext;
  int count;
  int totalSize;
  _TypeStat(this.ext, this.count, this.totalSize);
}
