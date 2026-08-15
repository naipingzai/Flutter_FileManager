// ignore_for_file: non_constant_identifier_names
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'native_library.dart';

// char* db_init(const char* data_dir)
typedef DbInitNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef DbInitDart = Pointer<Utf8> Function(Pointer<Utf8>);

// char* db_import_file(const char* src, const char* default_tags)
typedef DbImportNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef DbImportDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

// char* db_list_files(int parent_id)
typedef DbListNative = Pointer<Utf8> Function(Int32);
typedef DbListDart = Pointer<Utf8> Function(int);

// char* db_list_all(void)
typedef DbListAllNative = Pointer<Utf8> Function();
typedef DbListAllDart = Pointer<Utf8> Function();

// char* db_import_dir(const char* dir, const char* default_tags)
typedef DbImportDirNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef DbImportDirDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

// char* db_stats(void)
typedef DbStatsNative = Pointer<Utf8> Function();
typedef DbStatsDart = Pointer<Utf8> Function();

// char* db_search(const char* query)
typedef DbSearchNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef DbSearchDart = Pointer<Utf8> Function(Pointer<Utf8>);

// char* db_mkdir(const char* name, int parent_id)
typedef DbMkdirNative = Pointer<Utf8> Function(Pointer<Utf8>, Int32);
typedef DbMkdirDart = Pointer<Utf8> Function(Pointer<Utf8>, int);

// char* db_move(int file_id, int new_parent_id)
typedef DbMoveNative = Pointer<Utf8> Function(Int32, Int32);
typedef DbMoveDart = Pointer<Utf8> Function(int, int);

// char* db_rename(int file_id, const char* name)
typedef DbRenameNative = Pointer<Utf8> Function(Int32, Pointer<Utf8>);
typedef DbRenameDart = Pointer<Utf8> Function(int, Pointer<Utf8>);

// char* db_delete(int file_id)
typedef DbDeleteNative = Pointer<Utf8> Function(Int32);
typedef DbDeleteDart = Pointer<Utf8> Function(int);

// char* db_export_file(int file_id, const char* dest)
typedef DbExportNative = Pointer<Utf8> Function(Int32, Pointer<Utf8>);
typedef DbExportDart = Pointer<Utf8> Function(int, Pointer<Utf8>);

// char* db_tag_list(void)
typedef DbTagListNative = Pointer<Utf8> Function();
typedef DbTagListDart = Pointer<Utf8> Function();

// char* db_tag_counts(void)
typedef DbTagCountsNative = Pointer<Utf8> Function();
typedef DbTagCountsDart = Pointer<Utf8> Function();

// char* db_tag_rename(int tag_id, const char* name)
typedef DbTagRenameNative = Pointer<Utf8> Function(Int32, Pointer<Utf8>);
typedef DbTagRenameDart = Pointer<Utf8> Function(int, Pointer<Utf8>);

// char* db_tag_create(const char* name, const char* color)
typedef DbTagCreateNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef DbTagCreateDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
// char* db_tag_set_color(int tag_id, const char* color)
typedef DbTagColorNative = Pointer<Utf8> Function(Int32, Pointer<Utf8>);
typedef DbTagColorDart = Pointer<Utf8> Function(int, Pointer<Utf8>);

// char* db_tag_add_to_files(const char* file_ids, const char* tag_ids)
typedef DbTagAddNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef DbTagAddDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

// char* db_tag_remove_from_file(int file_id, int tag_id)
typedef DbTagRemoveNative = Pointer<Utf8> Function(Int32, Int32);
typedef DbTagRemoveDart = Pointer<Utf8> Function(int, int);

// char* db_tag_delete(int tag_id)
typedef DbTagDeleteNative = Pointer<Utf8> Function(Int32);
typedef DbTagDeleteDart = Pointer<Utf8> Function(int);

// char* db_files_by_tag(int tag_id)
typedef DbFilesByTagNative = Pointer<Utf8> Function(Int32);
typedef DbFilesByTagDart = Pointer<Utf8> Function(int);

// char* db_file_tags(int file_id)
typedef DbFileTagsNative = Pointer<Utf8> Function(Int32);
typedef DbFileTagsDart = Pointer<Utf8> Function(int);

// void db_free_string(char* str)
typedef DbFreeNative = Void Function(Pointer<Utf8>);
typedef DbFreeDart = void Function(Pointer<Utf8>);

/// database 模块 FFI 绑定（files/tags 数据库，导入式文件管理）
class DatabaseNative {
  static DatabaseNative? _instance;
  late final DynamicLibrary _lib;

  late final DbInitDart dbInit;
  late final DbImportDart dbImportFile;
  late final DbListDart dbListFiles;
  late final DbListAllDart dbListAll;
  late final DbImportDirDart dbImportDir;
  late final DbStatsDart dbStats;
  late final DbSearchDart dbSearch;
  late final DbMkdirDart dbMkdir;
  late final DbMoveDart dbMove;
  late final DbRenameDart dbRename;
  late final DbDeleteDart dbDelete;
  late final DbExportDart dbExportFile;
  late final DbTagListDart dbTagList;
  late final DbTagCountsDart dbTagCounts;
  late final DbTagRenameDart dbTagRename;
  late final DbTagCreateDart dbTagCreate;
  late final DbTagColorDart dbTagColor;
  late final DbTagAddDart dbTagAddToFiles;
  late final DbTagRemoveDart dbTagRemoveFromFile;
  late final DbTagDeleteDart dbTagDelete;
  late final DbFilesByTagDart dbFilesByTag;
  late final DbFileTagsDart dbFileTags;
  late final DbFreeDart dbFreeString;

  DatabaseNative._() {
    _lib = loadNativeLibrary();
    _bind();
  }

  factory DatabaseNative() {
    _instance ??= DatabaseNative._();
    return _instance!;
  }

  void _bind() {
    dbInit = _lib.lookupFunction<DbInitNative, DbInitDart>('db_init');
    dbImportFile = _lib.lookupFunction<DbImportNative, DbImportDart>('db_import_file');
    dbListFiles = _lib.lookupFunction<DbListNative, DbListDart>('db_list_files');
    dbListAll = _lib.lookupFunction<DbListAllNative, DbListAllDart>('db_list_all');
    dbImportDir = _lib.lookupFunction<DbImportDirNative, DbImportDirDart>('db_import_dir');
    dbStats = _lib.lookupFunction<DbStatsNative, DbStatsDart>('db_stats');
    dbSearch = _lib.lookupFunction<DbSearchNative, DbSearchDart>('db_search');
    dbMkdir = _lib.lookupFunction<DbMkdirNative, DbMkdirDart>('db_mkdir');
    dbMove = _lib.lookupFunction<DbMoveNative, DbMoveDart>('db_move');
    dbRename = _lib.lookupFunction<DbRenameNative, DbRenameDart>('db_rename');
    dbDelete = _lib.lookupFunction<DbDeleteNative, DbDeleteDart>('db_delete');
    dbExportFile = _lib.lookupFunction<DbExportNative, DbExportDart>('db_export_file');
    dbTagList = _lib.lookupFunction<DbTagListNative, DbTagListDart>('db_tag_list');
    dbTagCounts = _lib.lookupFunction<DbTagCountsNative, DbTagCountsDart>('db_tag_counts');
    dbTagRename = _lib.lookupFunction<DbTagRenameNative, DbTagRenameDart>('db_tag_rename');
    dbTagCreate = _lib.lookupFunction<DbTagCreateNative, DbTagCreateDart>('db_tag_create');
    dbTagColor = _lib.lookupFunction<DbTagColorNative, DbTagColorDart>('db_tag_set_color');
    dbTagAddToFiles =
        _lib.lookupFunction<DbTagAddNative, DbTagAddDart>('db_tag_add_to_files');
    dbTagRemoveFromFile =
        _lib.lookupFunction<DbTagRemoveNative, DbTagRemoveDart>('db_tag_remove_from_file');
    dbTagDelete = _lib.lookupFunction<DbTagDeleteNative, DbTagDeleteDart>('db_tag_delete');
    dbFilesByTag = _lib.lookupFunction<DbFilesByTagNative, DbFilesByTagDart>('db_files_by_tag');
    dbFileTags = _lib.lookupFunction<DbFileTagsNative, DbFileTagsDart>('db_file_tags');
    dbFreeString = _lib.lookupFunction<DbFreeNative, DbFreeDart>('db_free_string');
  }

  Map<String, dynamic>? _call(Pointer<Utf8> Function() fn) {
    final ptr = fn();
    final str = ptr.toDartString();
    dbFreeString(ptr);
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String? _err(Map<String, dynamic>? j) {
    if (j == null) return '调用失败';
    final e = j['error'];
    return (e is String && e.isNotEmpty) ? e : null;
  }

  String? init(String dataDir) {
    final pp = dataDir.toNativeUtf8();
    try {
      return _err(_call(() => dbInit(pp)));
    } finally {
      malloc.free(pp);
    }
  }

  Map<String, dynamic>? importFile(String src, [String defaultTags = '']) {
    final sp = src.toNativeUtf8();
    final tp = defaultTags.toNativeUtf8();
    try {
      return _call(() => dbImportFile(sp, tp));
    } finally {
      malloc.free(sp);
      malloc.free(tp);
    }
  }

  List<Map<String, dynamic>> listFiles([int parentId = -1]) {
    final j = _call(() => dbListFiles(parentId));
    if (_err(j) != null) return [];
    return ((j?['items'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> search(String query) {
    final qp = query.toNativeUtf8();
    try {
      final j = _call(() => dbSearch(qp));
      if (_err(j) != null) return [];
      return ((j?['items'] as List?) ?? []).cast<Map<String, dynamic>>();
    } finally {
      malloc.free(qp);
    }
  }

  ({int imported, int failed})? importDir(String dir, [String defaultTags = '']) {
    final dp = dir.toNativeUtf8();
    final tp = defaultTags.toNativeUtf8();
    try {
      final j = _call(() => dbImportDir(dp, tp));
      if (_err(j) != null) return null;
      return (imported: (j?['imported'] as int?) ?? 0, failed: (j?['failed'] as int?) ?? 0);
    } finally {
      malloc.free(dp);
      malloc.free(tp);
    }
  }

  Map<String, dynamic>? stats() => _call(() => dbStats());

  List<Map<String, dynamic>> listAll() {
    final j = _call(() => dbListAll());
    if (_err(j) != null) return [];
    return ((j?['items'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Map<String, dynamic>? mkdir(String name, int parentId) {
    final np = name.toNativeUtf8();
    try {
      return _call(() => dbMkdir(np, parentId));
    } finally {
      malloc.free(np);
    }
  }

  String? move(int fileId, int newParentId) {
    return _err(_call(() => dbMove(fileId, newParentId)));
  }

  String? rename(int fileId, String name) {
    final np = name.toNativeUtf8();
    try {
      return _err(_call(() => dbRename(fileId, np)));
    } finally {
      malloc.free(np);
    }
  }

  String? delete(int fileId) => _err(_call(() => dbDelete(fileId)));

  String? exportFile(int fileId, String dest) {
    final dp = dest.toNativeUtf8();
    try {
      return _err(_call(() => dbExportFile(fileId, dp)));
    } finally {
      malloc.free(dp);
    }
  }

  List<Map<String, dynamic>> tagList() {
    final j = _call(() => dbTagList());
    if (_err(j) != null) return [];
    return ((j?['items'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> tagCounts() {
    final j = _call(() => dbTagCounts());
    if (_err(j) != null) return [];
    return ((j?['items'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  String? tagRename(int tagId, String name) {
    final np = name.toNativeUtf8();
    try {
      return _err(_call(() => dbTagRename(tagId, np)));
    } finally {
      malloc.free(np);
    }
  }

  String? tagColor(int tagId, String color) {
    final cp = color.toNativeUtf8();
    try {
      return _err(_call(() => dbTagColor(tagId, cp)));
    } finally {
      malloc.free(cp);
    }
  }

  Map<String, dynamic>? tagCreate(String name, [String color = '']) {
    final np = name.toNativeUtf8();
    final cp = color.toNativeUtf8();
    try {
      return _call(() => dbTagCreate(np, cp));
    } finally {
      malloc.free(np);
      malloc.free(cp);
    }
  }

  /// 多文件批量加标签
  int tagAddToFiles(List<int> fileIds, List<int> tagIds) {
    final fp = fileIds.join(',').toNativeUtf8();
    final tp = tagIds.join(',').toNativeUtf8();
    try {
      final j = _call(() => dbTagAddToFiles(fp, tp));
      return (j?['added'] as int?) ?? 0;
    } finally {
      malloc.free(fp);
      malloc.free(tp);
    }
  }

  String? tagRemoveFromFile(int fileId, int tagId) =>
      _err(_call(() => dbTagRemoveFromFile(fileId, tagId)));

  String? tagDelete(int tagId) => _err(_call(() => dbTagDelete(tagId)));

  List<Map<String, dynamic>> filesByTag(int tagId) {
    final j = _call(() => dbFilesByTag(tagId));
    if (_err(j) != null) return [];
    return ((j?['items'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> fileTags(int fileId) {
    final j = _call(() => dbFileTags(fileId));
    if (_err(j) != null) return [];
    return ((j?['items'] as List?) ?? []).cast<Map<String, dynamic>>();
  }
}
