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
    return _iconCategoryNames[icon] ?? 'File${extension.isNotEmpty ? '.$extension' : ''}';
  }

  static String getBrokenSymbolicLinkName() => 'Broken Symbolic Link';

  static String _getIconCategory(MimeType mimeType) {
    // Simplified version - returns category string
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
