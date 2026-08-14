import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';

class BreadcrumbBar extends StatelessWidget {
  final String currentPath;
  final Function(String) onNavigate;

  const BreadcrumbBar({super.key, required this.currentPath, required this.onNavigate});

  List<String> get _parts {
    if (currentPath == '/') return ['/'];
    final parts = currentPath.split('/').where((p) => p.isNotEmpty).toList();
    final result = <String>['/'];
    String accum = '';
    for (final p in parts) {
      accum += '/$p';
      result.add(accum);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parts;
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: parts.length,
        separatorBuilder: (_, __) => const Icon(Icons.chevron_right, size: 18),
        itemBuilder: (ctx, i) {
          final p = parts[i];
          final label = p == '/' ? '/' : FileService.getFileName(p);
          final isLast = i == parts.length - 1;
          return Center(
            child: InkWell(
              onTap: isLast ? null : () => onNavigate(p),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                    color: isLast ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
