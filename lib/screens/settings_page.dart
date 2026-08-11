import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          _cardItem(context, '默认视图', '列表视图', Icons.view_list),
          _cardItem(context, '显示隐藏文件', '否', Icons.visibility_off),
          _cardItem(context, '排序方式', '按名称', Icons.sort),
          _cardItem(context, '目录优先', '是', Icons.folder_special),
          _cardItem(context, '主存储', '根目录 /', Icons.storage),
        ],
      ),
    );
  }

  Widget _cardItem(BuildContext context, String title, String subtitle, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
