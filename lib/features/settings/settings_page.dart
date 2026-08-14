import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_file_manager/core/native/system_ffi.dart';
import 'package:flutter_file_manager/features/file_manager/file_manager_state.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';

class SettingsPage extends StatefulWidget {
  final FileManagerState? state;
  const SettingsPage({super.key, this.state});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state ?? context.watch<FileManagerState>();
    return Scaffold(
      appBar: AppBar(title: const Text('基础设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          _sectionHeader(context, '存储'),
          FutureBuilder<DiskUsage?>(
            future: Future(() => state.getDiskUsage('/')),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data == null) return const SizedBox();
              final d = snap.data!;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '主存储',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: d.percent / 100),
                      const SizedBox(height: 8),
                      Text(
                        '${d.usedFormatted} / ${d.totalFormatted} (${d.percent.toStringAsFixed(1)}%)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _sectionHeader(context, '显示'),
          _switchItem(
            context,
            '显示隐藏文件',
            '在文件列表中显示以 . 开头的隐藏文件',
            Icons.visibility,
            value: state.currentTab.showHidden,
            onChanged: (_) => state.toggleHidden(),
          ),
          _switchItem(
            context,
            '目录优先',
            '排序时让文件夹排在文件前面',
            Icons.folder_special,
            value: state.currentTab.directoriesFirst,
            onChanged: (_) => state.toggleDirectoriesFirst(),
          ),
          const SizedBox(height: 16),
          _sectionHeader(context, '排序'),
          _sortOption(context, state, '按名称', SortMode.name, Icons.sort_by_alpha),
          _sortOption(context, state, '按大小', SortMode.size, Icons.data_usage),
          _sortOption(
            context,
            state,
            '按修改时间',
            SortMode.modified,
            Icons.schedule,
          ),
          _sortOption(context, state, '按类型', SortMode.type, Icons.label_outline),
          const SizedBox(height: 16),
          _sectionHeader(context, '平台'),
          _infoItem(
            context,
            '当前平台',
            SystemNative().osName,
            Icons.phone_android,
          ),
          _infoItem(context, '版本', '1.0.0', Icons.info_outline),
          _infoItem(context, '架构', 'Flutter + C++ (FFI)', Icons.code),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _switchItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon, {
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _sortOption(
    BuildContext context,
    FileManagerState state,
    String title,
    SortMode mode,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isSelected = state.currentTab.sortMode == mode;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.primary : null,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check, color: theme.colorScheme.primary)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => state.setSortMode(mode),
      ),
    );
  }

  Widget _infoItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
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
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
