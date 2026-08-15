import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';

class FileIcons {
  static IconData iconForEntry(FileEntry entry) {
    if (entry.isDirectory) return Icons.folder;
    if (entry.isSymlink) return Icons.link;
    final mime = entry.mimeType;
    if (mime.startsWith('image/')) return Icons.image;
    if (mime.startsWith('video/')) return Icons.movie;
    if (mime.startsWith('audio/')) return Icons.music_note;
    if (mime == 'application/pdf') return Icons.picture_as_pdf;
    if (mime == 'application/zip' ||
        mime == 'application/x-rar-compressed' ||
        mime == 'application/x-7z-compressed' ||
        mime == 'application/x-tar' ||
        mime == 'application/gzip') {
      return Icons.folder_zip;
    }
    if (mime.startsWith('text/')) return Icons.description;
    if (mime == 'application/vnd.android.package-archive') return Icons.android;
    if (entry.name.endsWith('.apk')) return Icons.android;
    if (entry.name.endsWith('.dart') ||
        entry.name.endsWith('.java') ||
        entry.name.endsWith('.kt') ||
        entry.name.endsWith('.cpp') ||
        entry.name.endsWith('.c') ||
        entry.name.endsWith('.h') ||
        entry.name.endsWith('.py') ||
        entry.name.endsWith('.js') ||
        entry.name.endsWith('.ts')) {
      return Icons.code;
    }
    return Icons.insert_drive_file;
  }

  /// 文件类型图标颜色 —— 全部取自 M3 色彩角色（ColorScheme），
  /// 不使用 M2 硬编码色板，保证明暗主题下均有正确对比度。
  static Color colorForEntry(FileEntry entry, ColorScheme scheme) {
    if (entry.isDirectory) return scheme.tertiary;
    if (entry.isSymlink) return scheme.secondary;
    final mime = entry.mimeType;
    if (mime.startsWith('image/')) return scheme.primary;
    if (mime.startsWith('video/')) return scheme.tertiary;
    if (mime.startsWith('audio/')) return scheme.secondary;
    if (mime == 'application/pdf') return scheme.error;
    if (mime == 'application/zip' ||
        mime == 'application/x-rar-compressed' ||
        mime == 'application/x-7z-compressed' ||
        mime == 'application/x-tar' ||
        mime == 'application/gzip') {
      return scheme.onSecondaryContainer;
    }
    if (mime.startsWith('text/')) return scheme.primaryContainer;
    if (entry.name.endsWith('.apk')) return scheme.inversePrimary;
    if (mime == 'application/x-executable') return scheme.onPrimaryContainer;
    return scheme.onSurfaceVariant;
  }
}
