import 'package:flutter/material.dart';
import 'path_models.dart';

// Port of navigation/BookmarkDirectory.kt
class BookmarkDirectory {
  final int id;
  final String? customName;
  final String path;

  BookmarkDirectory._(this.id, this.customName, this.path);

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

// Port of navigation/NavigationItem.kt
abstract class NavigationItem {
  abstract final int id;

  IconData? get icon => null;

  String getTitle();

  String? getSubtitle() => null;

  bool isChecked(NavigationItemListener listener) => false;

  void onClick(NavigationItemListener listener);

  bool onLongClick(NavigationItemListener listener) => false;
}

abstract class NavigationItemListener {
  String get currentPath;
  void navigateTo(String path);
  void navigateToRoot(String path);
  void closeNavigationDrawer();
}

// Port of navigation/StandardDirectory.kt
class StandardDirectory {
  final IconData icon;
  final String title;
  final String? customTitle;
  final String relativePath;
  final bool isEnabled;

  const StandardDirectory._({
    required this.icon,
    required this.title,
    this.customTitle,
    required this.relativePath,
    required this.isEnabled,
  });

  StandardDirectory({
    required IconData icon,
    required String title,
    required String relativePath,
    bool enabled = true,
  }) : this._(
         icon: icon,
         title: title,
         relativePath: relativePath,
         isEnabled: enabled,
       );

  int get id => relativePath.hashCode;

  String get key => relativePath;

  String get displayTitle =>
      customTitle?.isNotEmpty == true ? customTitle! : title;

  StandardDirectory withSettings(StandardDirectorySettings settings) =>
      StandardDirectory._(
        icon: icon,
        title: title,
        customTitle: settings.customTitle,
        relativePath: relativePath,
        isEnabled: settings.isEnabled,
      );

  StandardDirectorySettings toSettings() => StandardDirectorySettings(
    id: relativePath,
    customTitle: customTitle,
    isEnabled: isEnabled,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'customTitle': customTitle,
    'relativePath': relativePath,
    'isEnabled': isEnabled,
  };

  factory StandardDirectory.fromJson(
    Map<String, dynamic> json, {
    required IconData icon,
  }) => StandardDirectory._(
    icon: icon,
    title: json['title'] as String? ?? '',
    customTitle: json['customTitle'] as String?,
    relativePath: json['relativePath'] as String? ?? '',
    isEnabled: json['isEnabled'] as bool? ?? true,
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

// Port of navigation/NavigationRoot.kt
abstract class NavigationRoot {
  String get path;
  String getName();
}

// Concrete default root for Linux
class HomeNavigationRoot implements NavigationRoot {
  final String homePath;
  final String homeName;

  const HomeNavigationRoot({required this.homePath, this.homeName = 'Home'});

  @override
  String get path => homePath;

  @override
  String getName() => homeName;
}

class RootNavigationRoot implements NavigationRoot {
  final String rootName;

  const RootNavigationRoot({this.rootName = 'Root'});

  @override
  String get path => '/';

  @override
  String getName() => rootName;
}
