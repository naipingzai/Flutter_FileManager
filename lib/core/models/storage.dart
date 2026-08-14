import 'package:flutter/material.dart';

// Port of storage/Storage.kt
abstract class Storage {
  abstract final int id;

  IconData get icon => Icons.folder;

  final String? customName;

  Storage({this.customName});

  String getDefaultName();

  String getName() =>
      customName?.isNotEmpty == true ? customName! : getDefaultName();

  String get description;

  String? get path;

  bool get isVisible => true;

  Map<String, dynamic> toJson();

  Storage copyWith({String? customName, bool? isVisible});
}

// Port of storage/DeviceStorage.kt
abstract class DeviceStorage extends Storage {
  @override
  String get description => linuxPath;

  @override
  String? get path => linuxPath;

  String get linuxPath;

  final bool isVisible;

  DeviceStorage({super.customName, this.isVisible = true});

  @override
  DeviceStorage copyWith({String? customName, bool? isVisible});
}

// Port of FileSystemRoot
class FileSystemRoot extends DeviceStorage {
  FileSystemRoot({super.customName, super.isVisible = true});

  @override
  int get id => 'FileSystemRoot'.hashCode;

  @override
  IconData get icon => Icons.storage;

  @override
  String getDefaultName() => 'Root';

  @override
  String get linuxPath => '/';

  @override
  bool get isVisible => super.isVisible;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'FileSystemRoot',
    'customName': customName,
    'isVisible': isVisible,
  };

  @override
  FileSystemRoot copyWith({String? customName, bool? isVisible}) =>
      FileSystemRoot(
        customName: customName ?? this.customName,
        isVisible: isVisible ?? this.isVisible,
      );

  factory FileSystemRoot.fromJson(Map<String, dynamic> json) => FileSystemRoot(
    customName: json['customName'] as String?,
    isVisible: json['isVisible'] as bool? ?? true,
  );
}

// Port of PrimaryStorageVolume
class PrimaryStorageVolume extends DeviceStorage {
  final String rootPath;

  PrimaryStorageVolume({
    super.customName,
    this.rootPath = '/home',
    super.isVisible = true,
  });

  @override
  int get id => 'PrimaryStorageVolume'.hashCode;

  @override
  IconData get icon => Icons.sd_card;

  @override
  String getDefaultName() => 'Home';

  @override
  String get linuxPath => rootPath;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'PrimaryStorageVolume',
    'customName': customName,
    'rootPath': rootPath,
    'isVisible': isVisible,
  };

  @override
  PrimaryStorageVolume copyWith({String? customName, bool? isVisible}) =>
      PrimaryStorageVolume(
        customName: customName ?? this.customName,
        rootPath: rootPath,
        isVisible: isVisible ?? this.isVisible,
      );

  factory PrimaryStorageVolume.fromJson(Map<String, dynamic> json) =>
      PrimaryStorageVolume(
        customName: json['customName'] as String?,
        rootPath: json['rootPath'] as String? ?? '/home',
        isVisible: json['isVisible'] as bool? ?? true,
      );
}

Storage storageFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String?;
  switch (type) {
    case 'FileSystemRoot':
      return FileSystemRoot.fromJson(json);
    case 'PrimaryStorageVolume':
      return PrimaryStorageVolume.fromJson(json);
    default:
      return FileSystemRoot();
  }
}
