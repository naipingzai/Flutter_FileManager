// ignore_for_file: non_constant_identifier_names
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../native/file_ops_bindings.dart';

/// File viewer type for UI routing
enum FileViewerType {
  text,
  image,
  video,
  audio,
  pdf,
  csv,
  ebook,
  external,
  unknown,
}

/// File type enum (mirrors C++ FileType)
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

/// Sort mode for file lists
enum SortMode { name, size, modified, type }

/// View mode for file lists
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
  if (bytes < 1099511627776) {
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
  return '${(bytes / 1099511627776).toStringAsFixed(1)} TB';
}

/// Represents a single file/directory entry from the C++ backend.
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
  FileSize get fileSize => FileSize(size);
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

class DuplicateGroup {
  final String hash;
  final List<FileEntry> files;
  DuplicateGroup({required this.hash, required this.files});
}

class HexChunkResult {
  final String hex;
  final String ascii;
  final int length;
  HexChunkResult({required this.hex, required this.ascii, required this.length});
}

/// Pure C++ backend file service. All operations go through FFI to libfile_ops.so.
/// No Dart-native fallback – the C++ library is the single source of truth.
class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  late final FileOpsNative _n = FileOpsNative();

  // ---------- helpers ----------

  String _callJson(Pointer<Utf8> Function() fn) {
    final ptr = fn();
    final str = ptr.toDartString();
    _n.freeJson(ptr);
    return str;
  }

  /// Run an FFI function that writes to an error buffer.
  /// Returns null on success, or the error string.
  String? _callWithError(String Function(Pointer<Utf8> err, int errSize) fn) {
    final err = calloc<Char>(512).cast<Utf8>();
    try {
      final ret = fn(err, 512);
      if (ret != 0) return err.toDartString();
      return null;
    } finally {
      calloc.free(err);
    }
  }

  // ---------- static path helpers ----------

  static String getFileName(String path) {
    if (path.isEmpty || path == '/') return '/';
    final parts = path.split('/');
    return parts.isEmpty ? '/' : parts.last;
  }

  static String getParentPath(String path) {
    if (path.isEmpty || path == '/') return '/';
    final idx = path.lastIndexOf('/');
    if (idx <= 0) return '/';
    return path.substring(0, idx);
  }

  static String joinPath(String a, String b) {
    if (a.endsWith('/')) return '$a$b';
    return '$a/$b';
  }

  // ---------- directory & file queries ----------

  Future<String> getHomeDirectory() async {
    if (Platform.isAndroid) return '/storage/emulated/0';
    final j = jsonDecode(_callJson(_n.getHomeDir));
    return j['path'] ?? '/';
  }

  String getRootDirectory() => '/';

  List<FileEntry> listDirectory(String path, {bool showHidden = false}) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.listDirectory(pp, showHidden ? 1 : 0));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return [];
      return (j['items'] as List).map((e) => FileEntry.fromJson(e)).toList();
    } catch (_) {
      return [];
    } finally {
      calloc.free(pp);
    }
  }

  FileEntry? getFileInfo(String path) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.getFileInfo(pp));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return null;
      return FileEntry.fromJson(j['info']);
    } catch (_) {
      return null;
    } finally {
      calloc.free(pp);
    }
  }

  bool exists(String path) {
    final pp = path.toNativeUtf8();
    try {
      return _n.exists(pp) == 1;
    } finally {
      calloc.free(pp);
    }
  }

  bool isDirectory(String path) {
    final pp = path.toNativeUtf8();
    try {
      return _n.isDirectoryFn(pp) == 1;
    } finally {
      calloc.free(pp);
    }
  }

  // ---------- file operations ----------

  String? createDirectory(String path) {
    final pp = path.toNativeUtf8();
    final e = calloc<Char>(256).cast<Utf8>();
    try {
      if (_n.createDirectory(pp, e, 256) != 0) return e.toDartString();
      return null;
    } finally {
      calloc.free(pp);
      calloc.free(e);
    }
  }

  String? createFile(String path) {
    final pp = path.toNativeUtf8();
    final e = calloc<Char>(256).cast<Utf8>();
    try {
      if (_n.createFile(pp, e, 256) != 0) return e.toDartString();
      return null;
    } finally {
      calloc.free(pp);
      calloc.free(e);
    }
  }

  String? deleteFile(String path) {
    final pp = path.toNativeUtf8();
    final e = calloc<Char>(256).cast<Utf8>();
    try {
      if (_n.deleteFile(pp, e, 256) != 0) return e.toDartString();
      return null;
    } finally {
      calloc.free(pp);
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

  // ---------- search & tools ----------

  List<FileEntry> searchFiles(
    String dir,
    String pattern, {
    int maxResults = 1000,
  }) {
    final d = dir.toNativeUtf8(), pp = pattern.toNativeUtf8();
    try {
      final str = _callJson(() => _n.searchFiles(d, pp, maxResults));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return [];
      return (j['items'] as List).map((e) => FileEntry.fromJson(e)).toList();
    } catch (_) {
      return [];
    } finally {
      calloc.free(d);
      calloc.free(pp);
    }
  }

  FileHash? computeHash(String path) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.computeHash(pp));
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
      calloc.free(pp);
    }
  }

  DiskUsage getDiskUsage(String path) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.getDiskUsage(pp));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') {
        return DiskUsage(totalSpace: 0, freeSpace: 0, usedSpace: 0);
      }
      return DiskUsage(
        totalSpace: j['totalSpace'] ?? 0,
        freeSpace: j['freeSpace'] ?? 0,
        usedSpace: j['usedSpace'] ?? 0,
      );
    } catch (_) {
      return DiskUsage(totalSpace: 0, freeSpace: 0, usedSpace: 0);
    } finally {
      calloc.free(pp);
    }
  }

  List<DuplicateGroup> findDuplicates(String path) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.findDuplicates(pp, 10000));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return [];
      // C++ returns flat list of duplicate files; group them by size for display.
      final items = (j['items'] as List)
          .map((e) => FileEntry.fromJson(e))
          .toList();
      // Group by size as a simple hash proxy (C++ already filtered by CRC32)
      final map = <String, List<FileEntry>>{};
      for (final f in items) {
        final key = '${f.size}_${f.name}';
        map.putIfAbsent(key, () => []).add(f);
      }
      return map.entries
          .where((e) => e.value.length > 1)
          .map((e) => DuplicateGroup(hash: e.key, files: e.value))
          .toList();
    } catch (_) {
      return [];
    } finally {
      calloc.free(pp);
    }
  }

  List<FileEntry> findEmptyFiles(String path) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.findEmptyFiles(pp, 10000));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return [];
      return (j['items'] as List).map((e) => FileEntry.fromJson(e)).toList();
    } catch (_) {
      return [];
    } finally {
      calloc.free(pp);
    }
  }

  List<FileEntry> getRecentFiles(String path, {int limit = 30}) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.getRecentFiles(pp, 7, 10000));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return [];
      final items = (j['items'] as List)
          .map((e) => FileEntry.fromJson(e))
          .toList();
      items.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
      return items.take(limit).toList();
    } catch (_) {
      return [];
    } finally {
      calloc.free(pp);
    }
  }

  // ---------- viewer determination ----------

  FileViewerType determineViewer(String path) {
    final name = getFileName(path).toLowerCase();
    final ext = name.contains('.') ? '.${name.split('.').last}' : '';

    const imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.ico', '.tiff', '.tif', '.heic', '.avif'};
    const videoExts = {'.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.3gp'};
    const audioExts = {'.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a', '.opus'};
    const textExts = {'.txt', '.log', '.md', '.json', '.xml', '.yaml', '.yml', '.toml', '.ini', '.conf', '.css', '.js', '.py', '.rs', '.go', '.dart', '.sh', '.bat', '.c', '.cpp', '.h', '.hpp', '.java', '.kt', '.swift', '.html', '.htm'};

    if (imageExts.contains(ext)) return FileViewerType.image;
    if (videoExts.contains(ext)) return FileViewerType.video;
    if (audioExts.contains(ext)) return FileViewerType.audio;
    if (ext == '.pdf') return FileViewerType.pdf;
    if (ext == '.csv') return FileViewerType.csv;
    if (ext == '.epub') return FileViewerType.ebook;
    if (textExts.contains(ext)) return FileViewerType.text;
    return FileViewerType.external;
  }

  Future<void> openFile(String path) async {
    // On Linux, use xdg-open as a fallback
    if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }

  // ---------- file content I/O (for viewers) ----------

  String? readTextFile(String path) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.readTextFile(pp));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return null;
      return j['text'] as String?;
    } catch (_) {
      return null;
    } finally {
      calloc.free(pp);
    }
  }

  String? writeTextFile(String path, String content) {
    final pp = path.toNativeUtf8();
    final cc = content.toNativeUtf8();
    final e = calloc<Char>(512).cast<Utf8>();
    try {
      if (_n.writeTextFile(pp, cc, e, 512) != 0) return e.toDartString();
      return null;
    } finally {
      calloc.free(pp);
      calloc.free(cc);
      calloc.free(e);
    }
  }

  List<List<String>> readCsvFile(String path) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.readCsvFile(pp));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return [];
      final rows = j['rows'] as List;
      return rows.map((row) => (row as List).map((c) => c.toString()).toList()).toList();
    } catch (_) {
      return [];
    } finally {
      calloc.free(pp);
    }
  }

  HexChunkResult? readHexChunk(String path, int offset, int length) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.readHexChunk(pp, offset, length));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return null;
      return HexChunkResult(
        hex: j['hex'] ?? '',
        ascii: j['ascii'] ?? '',
        length: j['length'] ?? 0,
      );
    } catch (_) {
      return null;
    } finally {
      calloc.free(pp);
    }
  }

  String? readImageAsBase64(String path) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => _n.readImageAsBase64(pp));
      final j = jsonDecode(str);
      if (j['error'] != null && j['error'] != '') return null;
      return j['base64'] as String?;
    } catch (_) {
      return null;
    } finally {
      calloc.free(pp);
    }
  }

  // ---------- encryption / decryption ----------

  Future<String?> encryptFile(String src, String dst, String password) async {
    final s = src.toNativeUtf8();
    final d = dst.toNativeUtf8();
    final p = password.toNativeUtf8();
    final e = calloc<Char>(512).cast<Utf8>();
    try {
      if (_n.encryptFile(s, d, p, e, 512) != 0) return e.toDartString();
      return null;
    } finally {
      calloc.free(s);
      calloc.free(d);
      calloc.free(p);
      calloc.free(e);
    }
  }

  Future<String?> decryptFile(String src, String dst, String password) async {
    final s = src.toNativeUtf8();
    final d = dst.toNativeUtf8();
    final p = password.toNativeUtf8();
    final e = calloc<Char>(512).cast<Utf8>();
    try {
      if (_n.decryptFile(s, d, p, e, 512) != 0) return e.toDartString();
      return null;
    } finally {
      calloc.free(s);
      calloc.free(d);
      calloc.free(p);
      calloc.free(e);
    }
  }
}
