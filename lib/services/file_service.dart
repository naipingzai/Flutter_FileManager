// ignore_for_file: non_constant_identifier_names
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import '../native/file_ops_bindings.dart';

enum FileType {
  unknown(0),
  regular(1),
  directory(2),
  symlink(3),
  socket(4),
  fifo(5),
  blockDevice(6),
  charDevice(7);

  final int value;
  const FileType(this.value);
}

enum SortMode { name, size, modified, type }

enum ViewMode { list, grid }

FileType fileTypeFromInt(int v) => FileType.values.firstWhere(
  (e) => e.value == v,
  orElse: () => FileType.unknown,
);

String _formatPermissions(int mode) {
  String _tc(int t) {
    switch (t) {
      case 0x4:
        return 'd';
      case 0xA:
        return 'l';
      case 0x1:
        return 'p';
      case 0x2:
        return 'c';
      case 0x6:
        return 'b';
      case 0xC:
        return 's';
      default:
        return '-';
    }
  }

  return '${_tc(mode >> 12)}'
      '${(mode & 0400) != 0 ? "r" : "-"}${(mode & 0200) != 0 ? "w" : "-"}${(mode & 0100) != 0 ? "x" : "-"}'
      '${(mode & 040) != 0 ? "r" : "-"}${(mode & 020) != 0 ? "w" : "-"}${(mode & 010) != 0 ? "x" : "-"}'
      '${(mode & 04) != 0 ? "r" : "-"}${(mode & 02) != 0 ? "w" : "-"}${(mode & 01) != 0 ? "x" : "-"}';
}

String _formatDate(int epochSeconds) {
  if (epochSeconds <= 0) return '--';
  final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _formatSize(int bytes) {
  if (bytes < 0) return '--';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  if (bytes < 1099511627776)
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  return '${(bytes / 1099511627776).toStringAsFixed(1)} TB';
}

class FileEntry {
  final String name;
  final String path;
  final String symlinkTarget;
  final FileType type;
  final int size;
  final int modifiedTime;
  final int accessTime;
  final int createdTime;
  final int permissions;
  final int uid;
  final int gid;
  final String ownerName;
  final String groupName;
  final String mimeType;
  final bool isReadable;
  final bool isWritable;
  final bool isExecutable;
  final bool isHidden;

  FileEntry({
    required this.name,
    required this.path,
    this.symlinkTarget = '',
    required this.type,
    required this.size,
    required this.modifiedTime,
    this.accessTime = 0,
    this.createdTime = 0,
    required this.permissions,
    this.uid = 0,
    this.gid = 0,
    this.ownerName = '',
    this.groupName = '',
    this.mimeType = '',
    this.isReadable = true,
    this.isWritable = false,
    this.isExecutable = false,
    this.isHidden = false,
  });

  bool get isDirectory => type == FileType.directory;
  bool get isFile => type == FileType.regular;
  bool get isSymlink => type == FileType.symlink;
  String get sizeFormatted => isDirectory ? '--' : _formatSize(size);
  String get modifiedFormatted => _formatDate(modifiedTime);
  String get permissionsFormatted => _formatPermissions(permissions);
  String get octalPermissions =>
      '0${(permissions >> 6) & 7}${(permissions >> 3) & 7}${permissions & 7}';

  // Port of BasicFileAttributesExtensions.kt - fileSize
  FileSize get fileSize => FileSize(size);

  // Port of BasicFileAttributesExtensions.kt - lastModifiedInstant
  DateTime get lastModifiedDateTime =>
      DateTime.fromMillisecondsSinceEpoch(modifiedTime * 1000);

  factory FileEntry.fromJson(Map<String, dynamic> json) => FileEntry(
    name: json['name'] ?? '',
    path: json['path'] ?? '',
    symlinkTarget: json['symlinkTarget'] ?? '',
    type: fileTypeFromInt(json['type'] ?? 0),
    size: json['size'] ?? 0,
    modifiedTime: json['modifiedTime'] ?? 0,
    accessTime: json['accessTime'] ?? 0,
    createdTime: json['createdTime'] ?? 0,
    permissions: json['permissions'] ?? 0,
    uid: json['uid'] ?? 0,
    gid: json['gid'] ?? 0,
    ownerName: json['ownerName'] ?? '',
    groupName: json['groupName'] ?? '',
    mimeType: json['mimeType'] ?? '',
    isReadable: json['isReadable'] ?? false,
    isWritable: json['isWritable'] ?? false,
    isExecutable: json['isExecutable'] ?? false,
    isHidden: json['isHidden'] ?? false,
  );
}

class FileSize {
  final int bytes;
  const FileSize(this.bytes);
  String get humanReadable => _formatSize(bytes);
  bool get isHumanReadableInBytes => bytes <= 900;
}

class DiskUsage {
  final int totalSpace;
  final int freeSpace;
  final int usedSpace;
  DiskUsage({
    required this.totalSpace,
    required this.freeSpace,
    required this.usedSpace,
  });
  double get percent => totalSpace > 0 ? usedSpace / totalSpace * 100 : 0;
  String get totalFormatted => _formatSize(totalSpace);
  String get freeFormatted => _formatSize(freeSpace);
  String get usedFormatted => _formatSize(usedSpace);
}

class FileHash {
  final String md5, sha1, sha256, sha512, crc32;
  FileHash({
    required this.md5,
    required this.sha1,
    required this.sha256,
    required this.sha512,
    required this.crc32,
  });
}

class FileService {
  final FileOpsNative _n = FileOpsNative();

  String _callJson(Pointer<Utf8> Function() fn) {
    final ptr = fn();
    final str = ptr.toDartString();
    _n.freeJson(ptr);
    return str;
  }

  String getHomeDirectory() {
    final j = jsonDecode(_callJson(_n.getHomeDir));
    return j['path'] ?? '/';
  }

  String getRootDirectory() => '/';

  List<FileEntry> listDirectory(String path, {bool showHidden = false}) {
    final p = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.listDirectory(p, showHidden ? 1 : 0));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return [];
      return (j['items'] as List).map((e) => FileEntry.fromJson(e)).toList();
    } catch (_) {
      return [];
    } finally {
      calloc.free(p);
    }
  }

  FileEntry? getFileInfo(String path) {
    final p = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.getFileInfo(p));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return null;
      return FileEntry.fromJson(j['info']);
    } catch (_) {
      return null;
    } finally {
      calloc.free(p);
    }
  }

  bool exists(String path) {
    final p = path.toNativeUtf8();
    try {
      return _n.exists(p) == 1;
    } finally {
      calloc.free(p);
    }
  }

  bool isDirectory(String path) {
    final p = path.toNativeUtf8();
    try {
      return _n.isDirectoryFn(p) == 1;
    } finally {
      calloc.free(p);
    }
  }

  String? createDirectory(String path) {
    final p = path.toNativeUtf8();
    final e = calloc<Char>(256).cast<Utf8>();
    try {
      if (_n.createDirectory(p, e, 256) != 0) return e.toDartString();
      return null;
    } finally {
      calloc.free(p);
      calloc.free(e);
    }
  }

  String? createFile(String path) {
    final p = path.toNativeUtf8();
    final e = calloc<Char>(256).cast<Utf8>();
    try {
      if (_n.createFile(p, e, 256) != 0) return e.toDartString();
      return null;
    } finally {
      calloc.free(p);
      calloc.free(e);
    }
  }

  String? deleteFile(String path) {
    final p = path.toNativeUtf8();
    final e = calloc<Char>(256).cast<Utf8>();
    try {
      if (_n.deleteFile(p, e, 256) != 0) return e.toDartString();
      return null;
    } finally {
      calloc.free(p);
      calloc.free(e);
    }
  }

  String? rename(String oldPath, String newPath) {
    final o = oldPath.toNativeUtf8();
    final n = newPath.toNativeUtf8();
    final e = calloc<Char>(256).cast<Utf8>();
    try {
      if (_n.rename(o, n, e, 256) != 0) return e.toDartString();
      return null;
    } finally {
      calloc.free(o);
      calloc.free(n);
      calloc.free(e);
    }
  }

  String? copyFile(String src, String dst) {
    final s = src.toNativeUtf8();
    final d = dst.toNativeUtf8();
    final e = calloc<Char>(256).cast<Utf8>();
    try {
      if (_n.copyFile(s, d, e, 256) != 0) return e.toDartString();
      return null;
    } finally {
      calloc.free(s);
      calloc.free(d);
      calloc.free(e);
    }
  }

  String? moveFile(String src, String dst) {
    final s = src.toNativeUtf8();
    final d = dst.toNativeUtf8();
    final e = calloc<Char>(256).cast<Utf8>();
    try {
      if (_n.moveFile(s, d, e, 256) != 0) return e.toDartString();
      return null;
    } finally {
      calloc.free(s);
      calloc.free(d);
      calloc.free(e);
    }
  }

  List<FileEntry> searchFiles(
    String dir,
    String pattern, {
    int maxResults = 1000,
  }) {
    final d = dir.toNativeUtf8();
    final p = pattern.toNativeUtf8();
    try {
      final str = _callJson(() => _n.searchFiles(d, p, maxResults));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return [];
      return (j['items'] as List)
          .map(
            (e) => FileEntry(
              name: e['name'] ?? '',
              path: e['path'] ?? '',
              type: fileTypeFromInt(e['type'] ?? 0),
              size: e['size'] ?? 0,
              modifiedTime: e['modifiedTime'] ?? 0,
              permissions: 0,
              mimeType: 'application/octet-stream',
              isHidden: (e['name'] ?? '').startsWith('.'),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    } finally {
      calloc.free(d);
      calloc.free(p);
    }
  }

  FileHash? computeHash(String path) {
    final p = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.computeHash(p));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return null;
      return FileHash(
        md5: j['md5'] ?? '',
        sha1: j['sha1'] ?? '',
        sha256: j['sha256'] ?? '',
        sha512: j['sha512'] ?? '',
        crc32: j['crc32'] ?? '',
      );
    } catch (_) {
      return null;
    } finally {
      calloc.free(p);
    }
  }

  DiskUsage? getDiskUsage(String path) {
    final p = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.getDiskUsage(p));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return null;
      return DiskUsage(
        totalSpace: j['totalSpace'] ?? 0,
        freeSpace: j['freeSpace'] ?? 0,
        usedSpace: j['usedSpace'] ?? 0,
      );
    } catch (_) {
      return null;
    } finally {
      calloc.free(p);
    }
  }

  List<FileEntry> findDuplicates(String dir) {
    final d = dir.toNativeUtf8();
    try {
      final str = _callJson(() => _n.findDuplicates(d, 500));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return [];
      return (j['items'] as List)
          .map(
            (e) => FileEntry(
              name: e['name'] ?? '',
              path: e['path'] ?? '',
              type: FileType.regular,
              size: e['size'] ?? 0,
              modifiedTime: 0,
              permissions: 0,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    } finally {
      calloc.free(d);
    }
  }

  List<FileEntry> findEmptyFiles(String dir) {
    final d = dir.toNativeUtf8();
    try {
      final str = _callJson(() => _n.findEmptyFiles(d, 500));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return [];
      return (j['items'] as List)
          .map(
            (e) => FileEntry(
              name: e['name'] ?? '',
              path: e['path'] ?? '',
              type: fileTypeFromInt(e['type'] ?? 0),
              size: e['size'] ?? 0,
              modifiedTime: 0,
              permissions: 0,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    } finally {
      calloc.free(d);
    }
  }

  static String getParentPath(String path) {
    if (path == '/') return '/';
    final idx = path.lastIndexOf('/');
    return idx <= 0 ? '/' : path.substring(0, idx);
  }

  static String getFileName(String path) {
    if (path == '/') return '/';
    final idx = path.lastIndexOf('/');
    return idx < 0 ? path : path.substring(idx + 1);
  }

  static String joinPath(String parent, String child) =>
      parent.endsWith('/') ? '$parent$child' : '$parent/$child';
}
