import 'path_models.dart';

// Port of navigation/BookmarkDirectory.kt
class BookmarkDirectory {
  final int id;
  final String? customName;
  final String path;

  BookmarkDirectory({String? customName, required this.path})
    : id = DateTime.now().millisecondsSinceEpoch ^ path.hashCode,
      customName = customName;

  String get defaultName => pathName(path);

  String get name => customName?.isNotEmpty == true ? customName! : defaultName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'customName': customName,
    'path': path,
  };

  factory BookmarkDirectory.fromJson(Map<String, dynamic> json) =>
      BookmarkDirectory(
        customName: json['customName'] as String?,
        path: json['path'] as String? ?? '',
      );
}

// Port of navigation/StandardDirectorySettings.kt
class StandardDirectorySettings {
  final String id;
  final String? customTitle;
  final bool isEnabled;

  const StandardDirectorySettings({
    required this.id,
    this.customTitle,
    required this.isEnabled,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'customTitle': customTitle,
    'isEnabled': isEnabled,
  };

  factory StandardDirectorySettings.fromJson(Map<String, dynamic> json) =>
      StandardDirectorySettings(
        id: json['id'] as String? ?? '',
        customTitle: json['customTitle'] as String?,
        isEnabled: json['isEnabled'] as bool? ?? true,
      );
}
