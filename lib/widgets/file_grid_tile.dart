import 'package:flutter/material.dart';
import '../services/file_service.dart';
import '../utils/file_icons.dart';

class FileGridTile extends StatelessWidget {
  final FileEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const FileGridTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FileIcons.iconForEntry(entry), size: 48, color: FileIcons.colorForEntry(entry)),
              const SizedBox(height: 8),
              Text(
                entry.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              if (entry.isFile)
                Text(entry.sizeFormatted, style: TextStyle(fontSize: 10, color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
