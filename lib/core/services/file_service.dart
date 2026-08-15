// ignore_for_file: non_constant_identifier_names
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:image/image.dart' as imgLib;
import 'package:path/path.dart' as p;
import 'package:flutter_file_manager/core/native/media_ffi.dart';
import 'package:flutter_file_manager/core/native/system_ffi.dart';

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
  HexChunkResult({
    required this.hex,
    required this.ascii,
    required this.length,
  });
}

/// 由 media 静态库（stb_image）解码后的图片数据。
class DecodedImageData {
  final Uint8List bytes; // RGBA 像素数据
  final int width;
  final int height;
  DecodedImageData({
    required this.bytes,
    required this.width,
    required this.height,
  });
}

/// Pure C++ backend file service. All operations go through FFI to libfile_ops.so.
/// No Dart-native fallback – the C++ library is the single source of truth.
class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  // media 静态库（图片/电子书/视频/音频解码）
  late final MediaNative _media = MediaNative();

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
    // 统一通过 system 模块从 C++ 获取，Dart 不做平台判断。
    return SystemNative().homeDirectory;
  }

  String getRootDirectory() => SystemNative().rootDirectory;

  // ---------- file operations ----------

  FileEntry _entryFrom(FileSystemEntity e) {
    final name = e is Directory
        ? (e.path.endsWith('/') ? p.basename(e.path.substring(0, e.path.length - 1)) : p.basename(e.path))
        : p.basename(e.path);
    final isDir = e is Directory;
    final isLink = e is Link;
    var size = 0, modified = 0, accessed = 0, changed = 0, mode = 0;
    try {
      final st = e.statSync();
      size = st.size;
      modified = st.modified.millisecondsSinceEpoch ~/ 1000;
      accessed = st.accessed.millisecondsSinceEpoch ~/ 1000;
      changed = st.changed.millisecondsSinceEpoch ~/ 1000;
      mode = st.mode;
    } catch (_) {}
    return FileEntry(
      name: name,
      path: e.path,
      type: isDir ? FileType.directory : (isLink ? FileType.symlink : FileType.regular),
      size: isDir ? 0 : size,
      modifiedTime: modified,
      accessTime: accessed,
      createdTime: changed,
      permissions: mode & 0xFFF,
      uid: 0,
      gid: 0,
      isReadable: true,
      isWritable: false,
      isHidden: name.startsWith('.'),
    );
  }

  List<FileEntry> listDirectory(String path, {bool showHidden = false}) {
    final dir = Directory(path);
    if (!dir.existsSync()) return [];
    try {
      final list = dir.listSync(followLinks: false);
      return list
          .where((e) => showHidden || !p.basename(e.path).startsWith('.'))
          .map(_entryFrom)
          .toList();
    } catch (_) {
      return [];
    }
  }

  FileEntry? getFileInfo(String path) {
    final e = File(path);
    if (!e.existsSync()) return null;
    return _entryFrom(e);
  }

  bool exists(String path) => FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

  bool isDirectory(String path) => Directory(path).existsSync();

  String? createDirectory(String path) {
    try {
      Directory(path).createSync(recursive: true);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  String? createFile(String path) {
    try {
      File(path).createSync(recursive: true);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  String? deleteFile(String path) {
    try {
      final e = FileSystemEntity.typeSync(path);
      if (e == FileSystemEntityType.directory) {
        Directory(path).deleteSync(recursive: true);
      } else {
        File(path).deleteSync();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  String? rename(String oldPath, String newPath) {
    try {
      File(oldPath).renameSync(newPath);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  String? copyFile(String src, String dst) {
    try {
      File(src).copySync(dst);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  String? moveFile(String src, String dst) {
    try {
      File(src).renameSync(dst);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ---------- search & tools ----------

  List<FileEntry> searchFiles(
    String dir,
    String pattern, {
    int maxResults = 1000,
  }) {
    final results = <FileEntry>[];
    final root = Directory(dir);
    if (!root.existsSync()) return results;
    final stack = <Directory>[root];
    final regex = RegExp(pattern.replaceAll('*', '.*').replaceAll('?', '.'),
        caseSensitive: false);
    try {
      while (stack.isNotEmpty && results.length < maxResults) {
        final d = stack.removeLast();
        for (final e in d.listSync(followLinks: false)) {
          if (results.length >= maxResults) break;
          if (e is Directory) {
            stack.add(e);
          } else if (e is File && regex.hasMatch(p.basename(e.path))) {
            results.add(_entryFrom(e));
          }
        }
      }
    } catch (_) {}
    return results;
  }

  FileHash? computeHash(String path) {
    // 纯 Dart 实现（crypto 包 + 手写 CRC32），替代 C++ file_compute_hash
    try {
      final bytes = File(path).readAsBytesSync();
      final md5 = _hex(crypto.md5.convert(bytes).bytes);
      final sha1v = _hex(crypto.sha1.convert(bytes).bytes);
      final sha256v = _hex(crypto.sha256.convert(bytes).bytes);
      final sha512v = _hex(crypto.sha512.convert(bytes).bytes);
      return FileHash(
        md5: md5,
        sha1: sha1v,
        sha256: sha256v,
        sha512: sha512v,
        crc32: _crc32Hex(bytes),
      );
    } catch (_) {
      return null;
    }
  }

  String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// CRC32（IEEE 802.3，与 zlib 输出一致），返回 8 位十六进制小写。
  String _crc32Hex(List<int> data) {
    var crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc >> 1) ^ (0xEDB88320 & (-(crc & 1)));
      }
    }
    return (crc ^ 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  }

  /// 磁盘用量。Dart 无内置磁盘空间 API，返回全 0（由平台层提供时再填充）。
  DiskUsage getDiskUsage(String path) {
    return DiskUsage(totalSpace: 0, freeSpace: 0, usedSpace: 0);
  }

  List<DuplicateGroup> findDuplicates(String path) {    // 纯 Dart：递归收集文件，按 (size, crc32) 分组，报告重复
    final byKey = <String, List<FileEntry>>{};
    final root = Directory(path);
    if (!root.existsSync()) return [];
    final stack = <Directory>[root];
    try {
      while (stack.isNotEmpty) {
        final d = stack.removeLast();
        for (final e in d.listSync(followLinks: false)) {
          if (e is Directory) {
            stack.add(e);
          } else if (e is File) {
            final entry = _entryFrom(e);
            if (entry.size <= 0) continue;
            final crc = _crc32Hex(File(e.path).readAsBytesSync());
            final key = '${entry.size}_$crc';
            byKey.putIfAbsent(key, () => []).add(entry);
          }
        }
      }
    } catch (_) {}
    return byKey.entries
        .where((e) => e.value.length > 1)
        .map((e) => DuplicateGroup(hash: e.key, files: e.value))
        .toList();
  }

  List<FileEntry> findEmptyFiles(String path) {
    final results = <FileEntry>[];
    final root = Directory(path);
    if (!root.existsSync()) return results;
    final stack = <Directory>[root];
    try {
      while (stack.isNotEmpty) {
        final d = stack.removeLast();
        for (final e in d.listSync(followLinks: false)) {
          if (e is Directory) {
            results.add(_entryFrom(e));
            stack.add(e);
          } else if (e is File && e.lengthSync() == 0) {
            results.add(_entryFrom(e));
          }
        }
      }
    } catch (_) {}
    return results;
  }

  List<FileEntry> getRecentFiles(String path, {int limit = 30}) {
    final results = <FileEntry>[];
    final root = Directory(path);
    if (!root.existsSync()) return results;
    final stack = <Directory>[root];
    try {
      while (stack.isNotEmpty) {
        final d = stack.removeLast();
        for (final e in d.listSync(followLinks: false)) {
          if (e is Directory) {
            stack.add(e);
          } else if (e is File) {
            results.add(_entryFrom(e));
          }
        }
      }
    } catch (_) {}
    results.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
    return results.take(limit).toList();
  }

  // ---------- viewer determination ----------

  FileViewerType determineViewer(String path) {
    final name = getFileName(path).toLowerCase();
    final ext = name.contains('.') ? '.${name.split('.').last}' : '';

    const imageExts = {
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.svg',
      '.ico',
      '.tiff',
      '.tif',
      '.heic',
      '.avif',
    };
    const videoExts = {
      '.mp4',
      '.avi',
      '.mkv',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.m4v',
      '.3gp',
    };
    const audioExts = {
      '.mp3',
      '.wav',
      '.flac',
      '.aac',
      '.ogg',
      '.wma',
      '.m4a',
      '.opus',
    };
    const textExts = {
      '.txt',
      '.log',
      '.md',
      '.json',
      '.xml',
      '.yaml',
      '.yml',
      '.toml',
      '.ini',
      '.conf',
      '.css',
      '.js',
      '.py',
      '.rs',
      '.go',
      '.dart',
      '.sh',
      '.bat',
      '.c',
      '.cpp',
      '.h',
      '.hpp',
      '.java',
      '.kt',
      '.swift',
      '.html',
      '.htm',
    };

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
    // 纯 APP 内部实现，不再调用系统外部能力
    // 由调用方根据 determineViewer() 结果路由到内部 viewer
    throw UnsupportedError('外部打开已禁用，请使用 APP 内部 viewer');
  }

  // ---------- file content I/O (for viewers) ----------

  String? readTextFile(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      return f.readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  String? writeTextFile(String path, String content) {
    try {
      File(path).writeAsStringSync(content);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  List<List<String>> readCsvFile(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return [];
      return f
          .readAsLinesSync()
          .map((line) => line.split(','))
          .toList();
    } catch (_) {
      return [];
    }
  }

  HexChunkResult? readHexChunk(String path, int offset, int length) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      final raf = f.openSync();
      try {
        raf.setPositionSync(offset);
        final bytes = raf.readSync(length);
        return HexChunkResult(
          hex: bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
          ascii: String.fromCharCodes(bytes.map((b) => (b >= 32 && b < 127) ? b : 46)),
          length: bytes.length,
        );
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return null;
    }
  }

  String? readImageAsBase64(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      return base64Encode(f.readAsBytesSync());
    } catch (_) {
      return null;
    }
  }

  /// 通用二进制读取：视频/音频/PDF/电子书等所有 viewer 用。
  Uint8List? readFileData(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      return f.readAsBytesSync();
    } catch (_) {
      return null;
    }
  }

  // 派生方法（语义清晰）
  Uint8List? readVideoData(String path) => readFileData(path);
  Uint8List? readAudioData(String path) => readFileData(path);
  Uint8List? readPdfData(String path) => readFileData(path);
  Uint8List? readEbookData(String path) => readFileData(path);

  // ---------- media 静态库解码（图片/电子书） ----------

  /// 用 Dart image 包解码图片为 RGBA + 尺寸（替代 stb_image）。
  DecodedImageData? decodeImage(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      final img = imgLib.decodeImage(bytes);
      if (img == null) return null;
      return DecodedImageData(
        bytes: img.getBytes(order: imgLib.ChannelOrder.rgba),
        width: img.width,
        height: img.height,
      );
    } catch (_) {
      return null;
    }
  }

  /// 用 Dart image 包生成图片缩略图（替代 native stb_image）。
  /// 返回 { base64, width, height }；失败返回 null。
  Map<String, dynamic>? makeImageThumbnail(String path, int maxSize) {
    try {
      final bytes = File(path).readAsBytesSync();
      final img = imgLib.decodeImage(bytes);
      if (img == null) return null;
      final thumb = imgLib.copyResizeCropSquare(img, size: maxSize <= 0 ? 256 : maxSize);
      final rgba = thumb.getBytes(order: imgLib.ChannelOrder.rgba);
      return {
        'base64': base64Encode(rgba),
        'width': thumb.width,
        'height': thumb.height,
      };
    } catch (_) {
      return null;
    }
  }

  /// 用 media 静态库（miniz）提取 EPUB 正文。
  String? readEbookText(String path) => _media.extractEbookText(path);

  // ---------- 视频/音频解码 ----------

  /// 用 media 静态库（FFmpeg）打开视频。
  Pointer<Void>? openVideo(String path) => _media.openVideo(path);

  /// 为视频句柄预分配复用 RGBA 帧缓冲。
  void prepareVideoFrameBuffer(Pointer<Void> handle) =>
      _media.prepareFrameBuffer(handle);

  /// 获取视频信息（width, height, duration, fps）。
  Map<String, dynamic>? getVideoInfo(Pointer<Void> handle) =>
      _media.getVideoInfo(handle);

  /// 解码下一帧为裸 RGBA 字节（复用缓冲，避免 base64/JSON 往返）。
  ({Uint8List bytes, int width, int height, double timestamp})?
  nextVideoFrameRgba(Pointer<Void> handle) => _media.nextVideoFrameRgba(handle);

  /// 跳转到指定时间戳（秒）。
  bool seekVideo(Pointer<Void> handle, double timestamp) =>
      _media.seekVideo(handle, timestamp);

  /// 关闭视频句柄。
  void closeVideo(Pointer<Void> handle) => _media.closeVideo(handle);

  /// 用 media 静态库（FFmpeg）解码音频（完整 PCM，S16 交错）。
  Map<String, dynamic>? decodeAudio(String path) =>
      _media.decodeAudioFile(path);

  // ---------- 音频输出（平台层：ALSA/AAudio/AudioQueue/WASAPI） ----------

  /// 打开音频输出设备（采样率/声道/位深）。
  Pointer<Void>? audioOutputOpen(int sampleRate, int channels, int bits) =>
      _media.audioOutputOpen(sampleRate, channels, bits);

  /// 播放 PCM 数据（阻塞直到播放完成）。
  int audioOutputWrite(Pointer<Void> handle, Pointer<Uint8> pcm, int len) =>
      _media.audioOutputWrite(handle, pcm, len);

  /// 停止播放并清空缓冲。
  void audioOutputStop(Pointer<Void> handle) =>
      _media.audioOutputStop(handle);

  /// 关闭音频输出设备。
  void audioOutputClose(Pointer<Void> handle) =>
      _media.audioOutputClose(handle);

}
