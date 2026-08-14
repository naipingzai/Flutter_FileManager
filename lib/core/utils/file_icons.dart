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

  static Color colorForEntry(FileEntry entry) {
    if (entry.isDirectory) return Colors.amber;
    if (entry.isSymlink) return Colors.teal;
    final mime = entry.mimeType;
    if (mime.startsWith('image/')) return Colors.purple;
    if (mime.startsWith('video/')) return Colors.red;
    if (mime.startsWith('audio/')) return Colors.pink;
    if (mime == 'application/pdf') return Colors.redAccent;
    if (mime == 'application/zip' ||
        mime == 'application/x-rar-compressed' ||
        mime == 'application/x-7z-compressed' ||
        mime == 'application/x-tar' ||
        mime == 'application/gzip') {
      return Colors.brown;
    }
    if (mime.startsWith('text/')) return Colors.blue;
    if (entry.name.endsWith('.apk')) return Colors.green;
    if (mime == 'application/x-executable') return Colors.indigo;
    return Colors.blueGrey;
  }
}
