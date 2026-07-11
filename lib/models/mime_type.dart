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
}
