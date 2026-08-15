import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_file_manager/core/models/navigation.dart';

// Sort options
enum FileSortBy { name, type, size, lastModified }

enum FileSortOrder { ascending, descending }

enum FileViewType { list, grid }

enum OpenApkDefaultAction { install, view }

enum RootStrategy { never, auto, always }

class FileSortOptions {
  final FileSortBy by;
  final FileSortOrder order;
  final bool isDirectoriesFirst;

  const FileSortOptions(this.by, this.order, this.isDirectoriesFirst);

  Map<String, dynamic> toJson() => {
    'by': by.name,
    'order': order.name,
    'isDirectoriesFirst': isDirectoriesFirst,
  };

  factory FileSortOptions.fromJson(Map<String, dynamic> json) =>
      FileSortOptions(
        FileSortBy.values.byName(json['by'] as String? ?? 'name'),
        FileSortOrder.values.byName(json['order'] as String? ?? 'ascending'),
        json['isDirectoriesFirst'] as bool? ?? true,
      );
}

// Text ellipsize port of TextUtils.TruncateAt
enum TextEllipsize { start, middle, end, marquee }

class Settings {
  static final Settings _instance = Settings._internal();
  factory Settings() => _instance;
  Settings._internal();

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  static const String _keyStorages = 'pref_storages';
  static const String _keyDefaultDirectory = 'pref_file_list_default_directory';
  static const String _keyPersistentDrawerOpen =
      'pref_file_list_persistent_drawer_open';
  static const String _keyShowHiddenFiles = 'pref_file_list_show_hidden_files';
  static const String _keyViewType = 'pref_file_list_view_type';
  static const String _keySortOptions = 'pref_file_list_sort_options';
  static const String _keyCreateArchiveType = 'pref_create_archive_type';
  static const String _keyAnimation = 'pref_file_list_animation';
  static const String _keyFileNameEllipsize = 'pref_file_name_ellipsize';
  static const String _keyStandardDirectorySettings =
      'pref_standard_directory_settings';
  static const String _keyBookmarkDirectories = 'pref_bookmark_directories';
  static const String _keyRootStrategy = 'pref_root_strategy';
  static const String _keyArchiveFileNameEncoding =
      'pref_archive_file_name_encoding';
  static const String _keyOpenApkDefaultAction = 'pref_open_apk_default_action';

  Future<List<String>> getStorages() async {
    final prefs = await _prefs;
    return prefs.getStringList(_keyStorages) ?? <String>[];
  }

  Future<void> setStorages(List<String> value) async =>
      (await _prefs).setStringList(_keyStorages, value);

  Future<String> getDefaultDirectory() async {
    final prefs = await _prefs;
    return prefs.getString(_keyDefaultDirectory) ?? '/home';
  }

  Future<void> setDefaultDirectory(String value) async =>
      (await _prefs).setString(_keyDefaultDirectory, value);

  Future<bool> getPersistentDrawerOpen() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyPersistentDrawerOpen) ?? false;
  }

  Future<void> setPersistentDrawerOpen(bool value) async =>
      (await _prefs).setBool(_keyPersistentDrawerOpen, value);

  Future<bool> getShowHiddenFiles() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyShowHiddenFiles) ?? false;
  }

  Future<void> setShowHiddenFiles(bool value) async =>
      (await _prefs).setBool(_keyShowHiddenFiles, value);

  Future<FileViewType> getViewType() async {
    final prefs = await _prefs;
    final name = prefs.getString(_keyViewType);
    return FileViewType.values.byName(name ?? 'list');
  }

  Future<void> setViewType(FileViewType value) async =>
      (await _prefs).setString(_keyViewType, value.name);

  static const String _keyGridColumns = 'pref_grid_columns';
  Future<int> getGridColumns() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyGridColumns) ?? 0; // 0=按屏幕宽度自适应
  }

  Future<void> setGridColumns(int value) async =>
      (await _prefs).setInt(_keyGridColumns, value);

  Future<FileSortOptions> getSortOptions() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keySortOptions);
    if (raw == null) {
      return const FileSortOptions(
        FileSortBy.name,
        FileSortOrder.ascending,
        true,
      );
    }
    return FileSortOptions.fromJson(
      _decodeJsonMap(raw) ?? const <String, dynamic>{},
    );
  }

  Future<void> setSortOptions(FileSortOptions value) async =>
      (await _prefs).setString(_keySortOptions, _encodeJsonMap(value.toJson()));

  Future<int> getCreateArchiveType() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyCreateArchiveType) ?? 0; // 0 = zip
  }

  Future<void> setCreateArchiveType(int value) async =>
      (await _prefs).setInt(_keyCreateArchiveType, value);

  Future<bool> getFileListAnimation() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyAnimation) ?? true;
  }

  Future<void> setFileListAnimation(bool value) async =>
      (await _prefs).setBool(_keyAnimation, value);

  Future<TextEllipsize> getFileNameEllipsize() async {
    final prefs = await _prefs;
    final name = prefs.getString(_keyFileNameEllipsize);
    return TextEllipsize.values.byName(name ?? 'end');
  }

  Future<void> setFileNameEllipsize(TextEllipsize value) async =>
      (await _prefs).setString(_keyFileNameEllipsize, value.name);

  Future<List<StandardDirectorySettings>> getStandardDirectorySettings() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyStandardDirectorySettings);
    final list = _decodeJsonList(raw) ?? <Map<String, dynamic>>[];
    return list.map((e) => StandardDirectorySettings.fromJson(e)).toList();
  }

  Future<void> setStandardDirectorySettings(
    List<StandardDirectorySettings> value,
  ) async => (await _prefs).setString(
    _keyStandardDirectorySettings,
    _encodeJsonList(value.map((e) => e.toJson()).toList()),
  );

  Future<List<BookmarkDirectory>> getBookmarkDirectories() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyBookmarkDirectories);
    final list = _decodeJsonList(raw) ?? <Map<String, dynamic>>[];
    return list.map((e) => BookmarkDirectory.fromJson(e)).toList();
  }

  Future<void> setBookmarkDirectories(List<BookmarkDirectory> value) async =>
      (await _prefs).setString(
        _keyBookmarkDirectories,
        _encodeJsonList(value.map((e) => e.toJson()).toList()),
      );

  Future<RootStrategy> getRootStrategy() async {
    final prefs = await _prefs;
    final name = prefs.getString(_keyRootStrategy);
    return RootStrategy.values.byName(name ?? 'auto');
  }

  Future<void> setRootStrategy(RootStrategy value) async =>
      (await _prefs).setString(_keyRootStrategy, value.name);

  Future<String> getArchiveFileNameEncoding() async {
    final prefs = await _prefs;
    return prefs.getString(_keyArchiveFileNameEncoding) ?? 'UTF-8';
  }

  Future<void> setArchiveFileNameEncoding(String value) async =>
      (await _prefs).setString(_keyArchiveFileNameEncoding, value);

  Future<OpenApkDefaultAction> getOpenApkDefaultAction() async {
    final prefs = await _prefs;
    final name = prefs.getString(_keyOpenApkDefaultAction);
    return OpenApkDefaultAction.values.byName(name ?? 'install');
  }

  Future<void> setOpenApkDefaultAction(OpenApkDefaultAction value) async =>
      (await _prefs).setString(_keyOpenApkDefaultAction, value.name);

  Map<String, dynamic>? _decodeJsonMap(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String _encodeJsonMap(Map<String, dynamic> map) => jsonEncode(map);

  List<Map<String, dynamic>>? _decodeJsonList(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  String _encodeJsonList(List<Map<String, dynamic>> list) => jsonEncode(list);
}

// Port of BasicSettings.kt
class BasicSettings {
  static const String _prefsName = 'basic_settings';
  static const String _keyPrefix = 'file_op_';

  static Future<bool> isFileOperationEnabled(String operation) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefsName:$_keyPrefix$operation') ?? true;
  }

  static Future<void> setFileOperationEnabled(
    String operation,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefsName:$_keyPrefix$operation', enabled);
  }
}

// Port of UiSettingsManager.kt
class UiSettingsManager {
  static const String _keyFontScale = 'font_scale';
  static const String _keySpacingScale = 'spacing_scale';
  static const String _keyListItemHeightScale = 'list_item_height_scale';
  static const String _keyIconScale = 'icon_scale';
  static const String _keyScreenMarginScale = 'screen_margin_scale';
  static const String _keyDialogPaddingScale = 'dialog_padding_scale';
  static const String _keyButtonSpacingScale = 'button_spacing_scale';
  static const String _keyBlurIntensity = 'blur_intensity';

  static Future<SharedPreferences> _prefs() async {
    // Use a separate namespace by prefixing keys; SharedPreferences instance is per app.
    return SharedPreferences.getInstance();
  }

  static Future<double> getFontScale() async =>
      (await _prefs()).getDouble(_keyFontScale) ?? 1.0;

  static Future<void> setFontScale(double value) async =>
      (await _prefs()).setDouble(_keyFontScale, value);

  static Future<double> getSpacingScale() async =>
      (await _prefs()).getDouble(_keySpacingScale) ?? 1.0;

  static Future<void> setSpacingScale(double value) async =>
      (await _prefs()).setDouble(_keySpacingScale, value);

  static Future<double> getListItemHeightScale() async =>
      (await _prefs()).getDouble(_keyListItemHeightScale) ?? 1.0;

  static Future<void> setListItemHeightScale(double value) async =>
      (await _prefs()).setDouble(_keyListItemHeightScale, value);

  static Future<double> getIconScale() async =>
      (await _prefs()).getDouble(_keyIconScale) ?? 1.0;

  static Future<void> setIconScale(double value) async =>
      (await _prefs()).setDouble(_keyIconScale, value);

  static Future<double> getScreenMarginScale() async =>
      (await _prefs()).getDouble(_keyScreenMarginScale) ?? 1.0;

  static Future<void> setScreenMarginScale(double value) async =>
      (await _prefs()).setDouble(_keyScreenMarginScale, value);

  static Future<double> getDialogPaddingScale() async =>
      (await _prefs()).getDouble(_keyDialogPaddingScale) ?? 1.0;

  static Future<void> setDialogPaddingScale(double value) async =>
      (await _prefs()).setDouble(_keyDialogPaddingScale, value);

  static Future<double> getButtonSpacingScale() async =>
      (await _prefs()).getDouble(_keyButtonSpacingScale) ?? 1.0;

  static Future<void> setButtonSpacingScale(double value) async =>
      (await _prefs()).setDouble(_keyButtonSpacingScale, value);

  static Future<double> getBlurIntensity() async {
    final prefs = await _prefs();
    final stored = prefs.get(_keyBlurIntensity);
    if (stored is int) {
      return stored / 100.0;
    }
    if (stored is double) {
      return stored;
    }
    return 0.5;
  }

  static Future<void> setBlurIntensity(double value) async =>
      (await _prefs()).setInt(_keyBlurIntensity, (value * 100).toInt());

  static Future<T> getScaledDimension<T extends num>(
    T baseValue,
    ScaleType scaleType,
  ) async {
    final scale = await _scaleFor(scaleType);
    return (baseValue.toDouble() * scale) as T;
  }

  static Future<double> _scaleFor(ScaleType type) async {
    switch (type) {
      case ScaleType.font:
        return getFontScale();
      case ScaleType.spacing:
        return getSpacingScale();
      case ScaleType.listItemHeight:
        return getListItemHeightScale();
      case ScaleType.icon:
        return getIconScale();
      case ScaleType.screenMargin:
        return getScreenMarginScale();
      case ScaleType.dialogPadding:
        return getDialogPaddingScale();
      case ScaleType.buttonSpacing:
        return getButtonSpacingScale();
    }
  }

  // Applies font scale to the widget subtree.
  static Widget wrapFontScale(BuildContext context, Widget child) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: TextScaler.linear(
          mediaQuery.textScaler.scale(1.0) * getFontScaleSync(),
        ),
      ),
      child: child,
    );
  }

  static double getFontScaleSync() {
    // Best-effort sync fallback for build time.
    return 1.0;
  }
}

enum ScaleType {
  font,
  spacing,
  listItemHeight,
  icon,
  screenMargin,
  dialogPadding,
  buttonSpacing,
}
