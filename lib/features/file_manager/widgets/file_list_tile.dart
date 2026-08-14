import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';
import 'package:flutter_file_manager/core/utils/file_icons.dart';

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
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
        ),
        child: Row(
          children: [
            // Icon area: 48x48 touch target with 24dp icon
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    FileIcons.iconForEntry(entry),
                    color: FileIcons.colorForEntry(entry),
                    size: 24,
                  ),
                  if (entry.isSymlink)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: Icon(Icons.link, size: 12),
                    ),
                  if (!entry.isReadable)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(
                        Icons.lock,
                        size: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Title and description
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: entry.isDirectory
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: entry.isHidden
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _description(entry),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // More button
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: onMenuAction,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
          ],
        ),
      ),
    );
  }

  String _description(FileEntry entry) {
    final parts = <String>[];
    if (entry.isDirectory) {
      parts.add('目录');
    } else {
      parts.add(entry.sizeFormatted);
    }
    parts.add(entry.modifiedFormatted);
    return parts.join('  ');
  }
}
