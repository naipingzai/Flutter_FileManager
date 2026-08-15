import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/settings_service.dart';
import 'package:flutter_file_manager/features/library/display_settings_page.dart';

/// 设置页（design_skill 13.1，模式 A：顶部栏 + 卡片设置项列表）
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Settings _settings = Settings();
  String _defaultTag = '已导入';
  int _gridColumns = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await _settings.getGridColumns();
    if (mounted) setState(() => _gridColumns = c);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionLabel('常规', cs, tt),
          _settingCard(
            Icons.label_outlined,
            '默认标签名',
            '导入时自动打上的标签（默认"已导入"）',
            () => _editDefaultTag(),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _settingCard(
            Icons.grid_view_outlined,
            '网格视图列数',
            _gridSummary(),
            () => _editGridColumns(),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _settingCard(
            Icons.light_mode_outlined,
            '显示设置',
            '字体/间距/列表项高度等',
            () => _openDisplaySettings(),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(text, style: tt.titleSmall?.copyWith(color: cs.primary)),
    );
  }

  String _gridSummary() {
    return _gridColumns == 0 ? '自动（按宽度）' : '固定 $_gridColumns 列';
  }

  Widget _settingCard(IconData icon, String title, String sub, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(sub, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _editDefaultTag() async {
    final ctrl = TextEditingController(text: _defaultTag);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('默认标签名'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      setState(() => _defaultTag = name);
      // TODO: 持久化默认标签名，导入时使用
    }
  }

  Future<void> _editGridColumns() async {
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
      await _settings.setGridColumns(sel);
      setState(() => _gridColumns = sel);
    }
  }

  void _openDisplaySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DisplaySettingsPage()),
    );
  }
}
