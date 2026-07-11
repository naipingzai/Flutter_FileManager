// ignore_for_file: non_constant_identifier_names
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../services/file_service.dart';

// C function signatures
typedef JsonListDirNative = Pointer<Utf8> Function(Pointer<Utf8>, Int32);
typedef JsonListDirDart = Pointer<Utf8> Function(Pointer<Utf8>, int);
typedef JsonGetInfoNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef JsonGetInfoDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef JsonSearchNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef JsonSearchDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, int);
typedef JsonHashNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef JsonHashDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef JsonDiskNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef JsonDiskDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef JsonFindNative = Pointer<Utf8> Function(Pointer<Utf8>, Int32);
typedef JsonFindDart = Pointer<Utf8> Function(Pointer<Utf8>, int);
typedef JsonGetStrNative = Pointer<Utf8> Function();
typedef JsonGetStrDart = Pointer<Utf8> Function();
typedef FreeJsonNative = Void Function(Pointer<Utf8>);
typedef FreeJsonDart = void Function(Pointer<Utf8>);
typedef OpWithErrNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef OpWithErrDart = int Function(Pointer<Utf8>, Pointer<Utf8>, int);
typedef RenameNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef RenameDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef CopyMoveNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef CopyMoveDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef ExistsNative = Int32 Function(Pointer<Utf8>);
typedef ExistsDart = int Function(Pointer<Utf8>);

class FileOpsNative {
  static FileOpsNative? _instance;
  late final DynamicLibrary _lib;

  late final JsonListDirDart listDirectory;
  late final JsonGetInfoDart getFileInfo;
  late final JsonSearchDart searchFiles;
  late final JsonHashDart computeHash;
  late final JsonDiskDart getDiskUsage;
  late final JsonFindDart findDuplicates;
  late final JsonFindDart findEmptyFiles;
  late final JsonGetStrDart getHomeDir;
  late final JsonGetStrDart getRootDir;
  late final FreeJsonDart freeJson;
  late final OpWithErrDart createDirectory;
  late final OpWithErrDart createFile;
  late final OpWithErrDart deleteFile;
  late final RenameDart rename;
  late final CopyMoveDart copyFile;
  late final CopyMoveDart moveFile;
  late final ExistsDart exists;
  late final ExistsDart isDirectoryFn;

  FileOpsNative._() {
    _lib = _loadLibrary();
    _bindFunctions();
  }

  factory FileOpsNative() {
    _instance ??= FileOpsNative._();
    return _instance!;
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isLinux) return DynamicLibrary.open('libfile_ops.so');
    throw UnsupportedError('Platform not supported');
  }

  void _bindFunctions() {
    listDirectory = _lib.lookupFunction<JsonListDirNative, JsonListDirDart>('file_ops_json_list_directory');
    getFileInfo = _lib.lookupFunction<JsonGetInfoNative, JsonGetInfoDart>('file_ops_json_get_file_info');
    searchFiles = _lib.lookupFunction<JsonSearchNative, JsonSearchDart>('file_ops_json_search_files');
    computeHash = _lib.lookupFunction<JsonHashNative, JsonHashDart>('file_ops_json_compute_hash');
    getDiskUsage = _lib.lookupFunction<JsonDiskNative, JsonDiskDart>('file_ops_json_get_disk_usage');
    findDuplicates = _lib.lookupFunction<JsonFindNative, JsonFindDart>('file_ops_json_find_duplicates');
    findEmptyFiles = _lib.lookupFunction<JsonFindNative, JsonFindDart>('file_ops_json_find_empty_files');
    getHomeDir = _lib.lookupFunction<JsonGetStrNative, JsonGetStrDart>('file_ops_json_get_home_dir');
    getRootDir = _lib.lookupFunction<JsonGetStrNative, JsonGetStrDart>('file_ops_json_get_root_dir');
    freeJson = _lib.lookupFunction<FreeJsonNative, FreeJsonDart>('file_ops_free_json');
    createDirectory = _lib.lookupFunction<OpWithErrNative, OpWithErrDart>('file_ops_json_create_directory');
    createFile = _lib.lookupFunction<OpWithErrNative, OpWithErrDart>('file_ops_json_create_file');
    deleteFile = _lib.lookupFunction<OpWithErrNative, OpWithErrDart>('file_ops_json_delete_file');
    rename = _lib.lookupFunction<RenameNative, RenameDart>('file_ops_json_rename');
    copyFile = _lib.lookupFunction<CopyMoveNative, CopyMoveDart>('file_ops_json_copy_file');
    moveFile = _lib.lookupFunction<CopyMoveNative, CopyMoveDart>('file_ops_json_move_file');
    exists = _lib.lookupFunction<ExistsNative, ExistsDart>('file_ops_json_exists');
    isDirectoryFn = _lib.lookupFunction<ExistsNative, ExistsDart>('file_ops_json_is_directory');
  }
}
