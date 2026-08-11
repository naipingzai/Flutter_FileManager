import 'package:flutter/material.dart';
import '../services/file_service.dart';
import '../utils/file_icons.dart';

class FileGridTile extends StatelessWidget {
  final FileEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onMenuAction;

  const FileGridTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: selected ? 4 : 1,
        color: selected ? theme.colorScheme.primaryContainer : null,
        margin: const EdgeInsets.all(4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: Column(
          children: [
            // Thumbnail area with 1.78 aspect ratio
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Icon(
                    FileIcons.iconForEntry(entry),
                    size: 40,
                    color: FileIcons.colorForEntry(entry),
                  ),
                ),
              ),
            ),
            // Bottom single-line row
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      FileIcons.iconForEntry(entry),
                      size: 20,
                      color: FileIcons.colorForEntry(entry),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ),
                  if (onMenuAction != null)
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onPressed: onMenuAction,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 48,
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
