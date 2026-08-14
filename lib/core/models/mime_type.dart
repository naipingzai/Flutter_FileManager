// Port of file/MimeType.kt - full MIME type support
class MimeType {
  final String value;

  const MimeType(this.value);

  // Extract type part (before '/')
  String get type {
    final idx = value.indexOf('/');
    if (idx == -1) return value;
    return value.substring(0, idx);
  }

  // Extract subtype part (after '/', before ';')
  String get subtype {
    final slashIdx = value.indexOf('/');
    if (slashIdx == -1) return value;
    final semiIdx = value.indexOf(';');
    return value.substring(
      slashIdx + 1,
      semiIdx != -1 ? semiIdx : value.length,
    );
  }

  // Extract suffix (after '+', before ';')
  String? get suffix {
    final plusIdx = value.indexOf('+');
    if (plusIdx == -1) return null;
    final semiIdx = value.indexOf(';');
    if (semiIdx != -1 && plusIdx > semiIdx) return null;
    return value.substring(plusIdx + 1, semiIdx != -1 ? semiIdx : value.length);
  }

  // Extract parameters (after ';')
  String? get parameters {
    final semiIdx = value.indexOf(';');
    if (semiIdx != -1) return value.substring(semiIdx + 1);
    return null;
  }

  // Match against another MIME type
  bool match(MimeType mimeType) {
    final t = type;
    if (t != '*' && mimeType.type != t) return false;
    final s = subtype;
    if (s != '*' && mimeType.subtype != s) return false;
    final p = parameters;
    if (p != null && mimeType.parameters != p) return false;
    return true;
  }

  // Common MIME types (from MimeType.kt companion)
  static const MimeType any = MimeType('*/*');
  static const MimeType directory = MimeType('inode/directory');
  static const MimeType imageAny = MimeType('image/*');
  static const MimeType imageGif = MimeType('image/gif');
  static const MimeType imageSvgXml = MimeType('image/svg+xml');
  static const MimeType videoAny = MimeType('video/*');
  static const MimeType audioAny = MimeType('audio/*');
  static const MimeType pdf = MimeType('application/pdf');
  static const MimeType textPlain = MimeType('text/plain');
  static const MimeType generic = MimeType('application/octet-stream');
  static const MimeType apk = MimeType(
    'application/vnd.android.package-archive',
  );

  static MimeType of(String type, String subtype, String? parameters) {
    if (parameters != null) {
      return MimeType('$type/$subtype;$parameters');
    }
    return MimeType('$type/$subtype');
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  // Port of MimeTypeNameExtensions.kt - get human-readable name
  static String getName(MimeType mimeType, String extension) {
    final specialName = _specialPosixTypeNames[mimeType.value];
    if (specialName != null) return specialName;
    final icon = _getIconCategory(mimeType);
    return _iconCategoryNames[icon] ??
        'File${extension.isNotEmpty ? '.$extension' : ''}';
  }

  static String getBrokenSymbolicLinkName() => 'Broken Symbolic Link';

  static String _getIconCategory(MimeType mimeType) {
    final t = mimeType.type;
    final full = mimeType.value;
    if (full == 'application/vnd.android.package-archive') return 'apk';
    if (full == 'application/pdf') return 'pdf';
    if (t == 'image') return 'image';
    if (t == 'video') return 'video';
    if (t == 'audio') return 'audio';
    if (t == 'text') return 'text';
    if (t == 'inode' && full.contains('directory')) return 'directory';
    return 'generic';
  }

  // Port of MimeTypeConversionExtensions.kt - guessFromPath/guessFromExtension
  static MimeType guessFromPath(String path) {
    final parts = path.split('/');
    final fileName = parts.isNotEmpty ? parts.last : '';
    if (fileName.isEmpty || !fileName.contains('.')) return directory;
    final ext = fileName.split('.').last.toLowerCase();
    return guessFromExtension(ext);
  }

  static MimeType guessFromExtension(String extension) {
    final ext = extension.toLowerCase();
    final override = _extensionOverrideMap[ext];
    if (override != null) return MimeType(override);
    // Linux 无 Android 的 MimeTypeMap，默认回退为 generic
    return generic;
  }

  static MimeType? forSpecialPosixFileType(String type) {
    final value = _specialPosixFileTypeToMimeTypeMap[type];
    return value != null ? MimeType(value) : null;
  }

  // Port of MimeTypeConversionExtensions.kt - extension / intentType
  String? get extension => _extensionForMimeTypeMap[value];

  String get intentType => intentMimeType.value;

  MimeType get intentMimeType {
    final mapped = _mimeTypeToIntentMimeTypeMap[value];
    return mapped != null ? MimeType(mapped) : this;
  }

  static String intentTypeForCollection(List<MimeType> mimeTypes) {
    if (mimeTypes.isEmpty) return MimeType.any.value;
    final intentMimeTypes = mimeTypes.map((m) => m.intentMimeType).toList();
    final firstIntentMimeType = intentMimeTypes.first;
    if (intentMimeTypes.every((m) => firstIntentMimeType.match(m))) {
      return firstIntentMimeType.value;
    }
    final wildcardIntentMimeType = MimeType.of(
      firstIntentMimeType.type,
      '*',
      null,
    );
    if (intentMimeTypes.every((m) => wildcardIntentMimeType.match(m))) {
      return wildcardIntentMimeType.value;
    }
    return MimeType.any.value;
  }
}

// Port of specialPosixFileTypeToNameResMap from MimeTypeNameExtensions.kt
const Map<String, String> _specialPosixTypeNames = {
  'inode/chardevice': 'Character Device',
  'inode/blockdevice': 'Block Device',
  'inode/fifo': 'FIFO Pipe',
  'inode/symlink': 'Symbolic Link',
  'inode/socket': 'Socket',
};

// Port of getNameRes from MimeTypeNameExtensions.kt
const Map<String, String> _iconCategoryNames = {
  'apk': 'Android Package',
  'archive': 'Archive',
  'audio': 'Audio',
  'calendar': 'Calendar',
  'certificate': 'Certificate',
  'code': 'Source Code',
  'contact': 'Contact',
  'directory': 'Directory',
  'document': 'Document',
  'ebook': 'E-book',
  'email': 'Email',
  'font': 'Font',
  'generic': 'File',
  'image': 'Image',
  'pdf': 'PDF Document',
  'presentation': 'Presentation',
  'spreadsheet': 'Spreadsheet',
  'text': 'Text',
  'text_plain': 'Plain Text',
  'video': 'Video',
  'word': 'Word Document',
  'excel': 'Excel Spreadsheet',
  'powerpoint': 'PowerPoint Presentation',
};

// Port of supportedArchiveMimeTypes from MimeTypeTypeExtensions.kt
const Set<String> _supportedArchiveTypes = {
  'application/gzip',
  'application/java-archive',
  'application/rar',
  'application/zip',
  'application/zstd',
  'application/vnd.android.package-archive',
  'application/vnd.debian.binary-package',
  'application/vnd.ms-cab-compressed',
  'application/vnd.rar',
  'application/x-7z-compressed',
  'application/x-bzip2',
  'application/x-cab',
  'application/x-compress',
  'application/x-cpio',
  'application/x-deb',
  'application/x-debian-package',
  'application/x-gtar',
  'application/x-gtar-compressed',
  'application/x-iso9660-image',
  'application/x-java-archive',
  'application/x-lha',
  'application/x-lzma',
  'application/x-redhat-package-manager',
  'application/x-tar',
  'application/x-ustar',
  'application/x-xz',
};

// Port of mobiMimeTypes from MimeTypeTypeExtensions.kt
const Set<String> _mobiTypes = {
  'application/x-mobipocket-ebook',
  'application/vnd.amazon.ebook',
  'application/vnd.amazon.mobi8-ebook',
};

// Port of extensionToMimeTypeOverrideMap from MimeTypeConversionExtensions.kt
const Map<String, String> _extensionOverrideMap = {
  'csv': 'text/csv',
  'sh': 'application/x-sh',
  'bz': 'application/x-bzip',
  'bz2': 'application/x-bzip2',
  'z': 'application/x-compress',
  'lzma': 'application/x-lzma',
  'p7b': 'application/x-pkcs7-certificates',
  'spc': 'application/x-pkcs7-certificates',
  'ts': 'application/typescript',
  'py3': 'text/x-python',
  'py3x': 'text/x-python',
  'pyx': 'text/x-python',
  'wsgi': 'text/x-python',
  'yml': 'application/yaml',
  'asm': 'text/x-asm',
  's': 'text/x-asm',
  'cs': 'text/x-csharp',
  'azw': 'application/vnd.amazon.ebook',
  'ibooks': 'application/x-ibooks+zip',
  'msg': 'application/vnd.ms-outlook',
  'mkd': 'text/markdown',
  'conf': 'text/plain',
  'ini': 'text/plain',
  'list': 'text/plain',
  'log': 'text/plain',
  'prop': 'text/plain',
  'properties': 'text/plain',
  'rc': 'text/plain',
};

// Port of specialPosixFileTypeToMimeTypeMap from MimeTypeConversionExtensions.kt
const Map<String, String> _specialPosixFileTypeToMimeTypeMap = {
  'character_device': 'inode/chardevice',
  'block_device': 'inode/blockdevice',
  'fifo': 'inode/fifo',
  'symbolic_link': 'inode/symlink',
  'socket': 'inode/socket',
};

// Port of mimeTypeToIntentMimeTypeMap from MimeTypeConversionExtensions.kt
const Map<String, String> _mimeTypeToIntentMimeTypeMap = {
  'application/ecmascript': 'text/ecmascript',
  'application/javascript': 'text/javascript',
  'application/json': 'text/json',
  'application/typescript': 'text/typescript',
  'application/yaml': 'text/x-yaml',
  'application/x-sh': 'text/x-shellscript',
  'application/x-shellscript': 'text/x-shellscript',
  'application/octet-stream': '*/*',
};

// Best-effort reverse mapping for MimeType.extension on Linux
const Map<String, String> _extensionForMimeTypeMap = {
  'text/plain': 'txt',
  'text/html': 'html',
  'text/css': 'css',
  'text/javascript': 'js',
  'application/javascript': 'js',
  'application/json': 'json',
  'application/xml': 'xml',
  'text/xml': 'xml',
  'application/pdf': 'pdf',
  'application/zip': 'zip',
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/gif': 'gif',
  'image/svg+xml': 'svg',
  'video/mp4': 'mp4',
  'audio/mpeg': 'mp3',
  'application/vnd.android.package-archive': 'apk',
};

// Port of MimeTypeTypeExtensions.kt - type checking properties
extension MimeTypeTypeExtensions on MimeType {
  bool get isApk =>
      this == MimeType.apk ||
      value == 'application/vnd.android.package-archive';
  bool get isSupportedArchive => _supportedArchiveTypes.contains(value);
  bool get isImage => type == 'image';
  bool get isAudio => type == 'audio';
  bool get isVideo => type == 'video';
  bool get isMedia => isAudio || isVideo;
  bool get isPdf => value == 'application/pdf';
  bool get isMobi => _mobiTypes.contains(value);
  bool get isEpub => value == 'application/epub+zip';
  bool get isEbook => isMobi || isEpub;
  bool get isCsv =>
      value == 'text/csv' || value == 'text/comma-separated-values';
  bool get isText => type == 'text';
}
