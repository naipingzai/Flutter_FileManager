import 'package:flutter_file_manager/core/native/database_ffi.dart';
import 'package:flutter_file_manager/core/native/system_ffi.dart';

/// 数据库服务：导入式文件管理的核心。
/// 所有导入的文件进入内部数据库（应用私有目录），基于 files/tags 管理。
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late final DatabaseNative _db = DatabaseNative();
  late final SystemNative _sys = SystemNative();
  bool _inited = false;
  late final String _dataDir;

  String? init() {
    if (_inited) return null;
    // 数据存到应用私有目录下的 database/（files.db + files/）
    _dataDir = '${_sys.standardDir('app_data')}/database';
    final err = _db.init(_dataDir);
    if (err == null) _inited = true;
    return err;
  }

  String get dataDir => _dataDir;

  // ---- 导入 ----

  /// 导入系统文件（复制进内部目录 + 打默认标签）。返回文件记录，失败返回 null。
  Map<String, dynamic>? importFile(String src, {List<String> defaultTags = const []}) {
    init();
    return _db.importFile(src, defaultTags.join(','));
  }

  // ---- 查询 ----

  List<Map<String, dynamic>> listFiles([int parentId = -1]) {
    init();
    return _db.listFiles(parentId);
  }

  List<Map<String, dynamic>> search(String query) {
    init();
    return _db.search(query);
  }

  ({int imported, int failed})? importDir(String dir) {
    init();
    return _db.importDir(dir, '已导入');
  }

  Map<String, dynamic>? stats() {
    init();
    return _db.stats();
  }

  List<Map<String, dynamic>> listAll() {
    init();
    return _db.listAll();
  }

  Map<String, dynamic>? mkdir(String name, int parentId) {
    init();
    return _db.mkdir(name, parentId);
  }

  String? move(int fileId, int newParentId) => _db.move(fileId, newParentId);
  String? rename(int fileId, String name) => _db.rename(fileId, name);
  String? delete(int fileId) => _db.delete(fileId);

  String? exportFile(int fileId, String dest) => _db.exportFile(fileId, dest);

  // ---- 标签 ----

  List<Map<String, dynamic>> tags() => _db.tagList();

  List<Map<String, dynamic>> tagCounts() => _db.tagCounts();

  String? renameTag(int tagId, String name) =>
      _db.tagRename(tagId, name);

  String? tagColor(int tagId, String color) =>
      _db.tagColor(tagId, color);

  Map<String, dynamic>? createTag(String name, [String color = '']) =>
      _db.tagCreate(name, color);

  /// 多文件批量加标签
  int addTagsToFiles(List<int> fileIds, List<int> tagIds) =>
      _db.tagAddToFiles(fileIds, tagIds);

  String? removeTagFromFile(int fileId, int tagId) =>
      _db.tagRemoveFromFile(fileId, tagId);

  String? deleteTag(int tagId) => _db.tagDelete(tagId);

  List<Map<String, dynamic>> filesByTag(int tagId) => _db.filesByTag(tagId);

  List<Map<String, dynamic>> fileTags(int fileId) => _db.fileTags(fileId);
}
