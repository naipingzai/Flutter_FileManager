class Formatters {
  static String formatSize(int bytes) {
    if (bytes < 0) return '--';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes < 1099511627776) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    return '${(bytes / 1099511627776).toStringAsFixed(1)} TB';
  }

  static String formatDate(int epochSeconds) {
    if (epochSeconds <= 0) return '--';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String formatPermissions(int mode) {
    return '${_typeChar(mode >> 12)}'
        '${(mode & 0400) != 0 ? 'r' : '-'}${(mode & 0200) != 0 ? 'w' : '-'}${(mode & 0100) != 0 ? 'x' : '-'}'
        '${(mode & 040) != 0 ? 'r' : '-'}${(mode & 020) != 0 ? 'w' : '-'}${(mode & 010) != 0 ? 'x' : '-'}'
        '${(mode & 04) != 0 ? 'r' : '-'}${(mode & 02) != 0 ? 'w' : '-'}${(mode & 01) != 0 ? 'x' : '-'}';
  }

  static String _typeChar(int type) {
    switch (type) {
      case 0x4: return 'd';
      case 0xA: return 'l';
      case 0x1: return 'p';
      case 0x2: return 'c';
      case 0x6: return 'b';
      case 0xC: return 's';
      default: return '-';
    }
  }

  static String formatOctalPermissions(int mode) {
    return '0${(mode >> 6) & 7}${(mode >> 3) & 7}${mode & 7}';
  }
}

  // From FileSize.kt - whether size should be shown in raw bytes
  static bool isHumanReadableInBytes(int value) => value <= 900;

  // From FileSize.kt - format size in raw bytes with pluralization
  static String formatInBytes(int value) {
    return '$value bytes';
  }
}
