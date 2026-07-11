import 'package:flutter/material.dart';
import '../services/file_service.dart';
import '../utils/file_icons.dart';

class FileListTile extends StatelessWidget {
  final FileEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenuAction;
  final String menuAction;

  const FileListTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onMenuAction,
    this.menuAction = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      leading: Stack(
        children: [
          Icon(FileIcons.iconForEntry(entry), color: FileIcons.colorForEntry(entry), size: 32),
          if (entry.isSymlink)
            Positioned(
              right: 0, bottom: 0,
              child: Icon(Icons.link, size: 12, color: theme.colorScheme.outline),
            ),
          if (!entry.isReadable)
            Positioned(
              right: 0, top: 0,
              child: Icon(Icons.lock, size: 12, color: theme.colorScheme.error),
            ),
        ],
      ),
      title: Text(
        entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: entry.isDirectory ? FontWeight.w600 : FontWeight.normal,
          color: entry.isHidden ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: Text(
        '${entry.sizeFormatted}  ${entry.modifiedFormatted}  ${entry.permissionsFormatted}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (_) => onMenuAction(),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'open', child: Text('打开')),
          const PopupMenuItem(value: 'rename', child: Text('重命名')),
          const PopupMenuItem(value: 'copy', child: Text('复制')),
          const PopupMenuItem(value: 'move', child: Text('移动')),
          const PopupMenuItem(value: 'delete', child: Text('删除')),
          const PopupMenuItem(value: 'properties', child: Text('属性')),
          const PopupMenuItem(value: 'hash', child: Text('计算校验和')),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
