import 'package:flutter/material.dart';
import '../services/file_service.dart';

class FileIcons {
  static IconData iconForEntry(FileEntry e) {
    if (e.isDirectory) return Icons.folder;
    final mime = e.mimeType;
    final ext = e.name.contains('.') ? e.name.split('.').last.toLowerCase() : '';

    if (mime.startsWith('image/') || ['jpg','jpeg','png','gif','bmp','svg','webp','ico','tiff','heic','avif'].contains(ext)) return Icons.image;
    if (mime.startsWith('video/') || ['mp4','avi','mkv','mov','wmv','flv','webm','m4v','3gp'].contains(ext)) return Icons.movie;
    if (mime.startsWith('audio/') || ['mp3','wav','flac','aac','ogg','wma','m4a','opus'].contains(ext)) return Icons.music_note;
    if (mime == 'application/pdf' || ext == 'pdf') return Icons.picture_as_pdf;
    if (mime.contains('zip') || mime.contains('tar') || mime.contains('archive') || mime.contains('compressed') ||
        ['zip','tar','gz','bz2','xz','7z','rar','zst','lz4','iso','deb','rpm'].contains(ext)) return Icons.archive;
    if (mime.startsWith('text/') || ['txt','md','json','xml','csv','log','ini','conf','yaml','yml','toml'].contains(ext)) return Icons.description;
    if (['c','cpp','h','hpp','java','py','rs','go','kt','swift','dart','sh','bat','ps1','js','ts','html','css'].contains(ext)) return Icons.code;
    if (['doc','docx','odt','rtf'].contains(ext)) return Icons.article;
    if (['xls','xlsx','ods'].contains(ext)) return Icons.table_chart;
    if (['ppt','pptx','odp'].contains(ext)) return Icons.slideshow;
    if (['db','sqlite','sql'].contains(ext)) return Icons.storage;
    if (['exe','so','dll','bin','apk','appimage'].contains(ext)) return Icons.apps;
    if (e.isSymlink) return Icons.link;
    return Icons.insert_drive_file;
  }

  static Color colorForEntry(FileEntry e) {
    if (e.isDirectory) return Colors.amber.shade700;
    final ext = e.name.contains('.') ? e.name.split('.').last.toLowerCase() : '';
    if (['jpg','jpeg','png','gif','bmp','svg','webp','ico','heic','avif'].contains(ext)) return Colors.green;
    if (['mp4','avi','mkv','mov','wmv','flv','webm'].contains(ext)) return Colors.purple;
    if (['mp3','wav','flac','aac','ogg','wma','m4a'].contains(ext)) return Colors.orange;
    if (ext == 'pdf') return Colors.red;
    if (['zip','tar','gz','bz2','xz','7z','rar','zst'].contains(ext)) return Colors.brown;
    if (['c','cpp','h','hpp','java','py','rs','go','kt','swift','dart','sh','js','ts','html','css'].contains(ext)) return Colors.teal;
    if (['txt','md','json','xml','csv','log','ini','conf','yaml'].contains(ext)) return Colors.blue;
    return Colors.grey.shade600;
  }
}
