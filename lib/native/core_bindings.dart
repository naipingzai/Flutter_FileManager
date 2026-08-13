// ignore_for_file: non_constant_identifier_names
//
// core - Unified native bindings (file_ops + fs_text 合并)
// 通过 Dart FFI 调用 native/core 静态库（直接集成进可执行文件）
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ============================================================
// ====================  FILE OPS BINDINGS  ====================
// ============================================================

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
typedef JsonRecentNative = Pointer<Utf8> Function(Pointer<Utf8>, Int32, Int32);
typedef JsonRecentDart = Pointer<Utf8> Function(Pointer<Utf8>, int, int);
typedef EncryptDecryptNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef EncryptDecryptDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef JsonPathNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef JsonPathDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef WriteTextNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef WriteTextDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef JsonHexNative = Pointer<Utf8> Function(Pointer<Utf8>, Int64, Int32);
typedef JsonHexDart = Pointer<Utf8> Function(Pointer<Utf8>, int, int);
// 权限/链接操作
typedef AccessNative = Int32 Function(Pointer<Utf8>, Int32);
typedef AccessDart = int Function(Pointer<Utf8>, int);
typedef ChownNative = Int32 Function(Pointer<Utf8>, Uint32, Uint32, Pointer<Utf8>, Int32);
typedef ChownDart = int Function(Pointer<Utf8>, int, int, Pointer<Utf8>, int);
typedef SymlinkNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef SymlinkDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef LinkNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef LinkDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
// 文件工具
typedef ChmodNative = Int32 Function(Pointer<Utf8>, Uint32, Pointer<Utf8>, Int32);
typedef ChmodDart = int Function(Pointer<Utf8>, int, Pointer<Utf8>, int);
typedef CompareNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef CompareDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef SplitFileNative = Int32 Function(Pointer<Utf8>, Int64, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef SplitFileDart = int Function(Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>, int);
typedef MergeFilesNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef MergeFilesDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);

// ============================================================
// ====================  TEXT OPS BINDINGS  ====================
// ============================================================

typedef FsTextCreateNative = Pointer<Void> Function();
typedef FsTextCreateDart = Pointer<Void> Function();
typedef FsTextDestroyNative = Void Function(Pointer<Void> handle);
typedef FsTextDestroyDart = void Function(Pointer<Void> handle);
typedef FsTextOpenNative = Int32 Function(Pointer<Void> handle, Pointer<Utf8> path);
typedef FsTextOpenDart = int Function(Pointer<Void> handle, Pointer<Utf8> path);
typedef FsTextCloseNative = Void Function(Pointer<Void> handle);
typedef FsTextCloseDart = void Function(Pointer<Void> handle);
typedef FsTextIsOpenNative = Int32 Function(Pointer<Void> handle);
typedef FsTextIsOpenDart = int Function(Pointer<Void> handle);
typedef FsTextSizeNative = Size Function(Pointer<Void> handle);
typedef FsTextSizeDart = int Function(Pointer<Void> handle);
typedef FsTextPathNative = Pointer<Utf8> Function(Pointer<Void> handle);
typedef FsTextPathDart = Pointer<Utf8> Function(Pointer<Void> handle);
typedef FsTextReadNative = Size Function(
  Pointer<Void> handle,
  Size offset,
  Size length,
  Pointer<Uint8> buffer,
  Size bufferSize,
);
typedef FsTextReadDart = int Function(
  Pointer<Void> handle,
  int offset,
  int length,
  Pointer<Uint8> buffer,
  int bufferSize,
);
typedef FsTextLineCountNative = Size Function(Pointer<Void> handle);
typedef FsTextLineCountDart = int Function(Pointer<Void> handle);
typedef FsTextReadLineNative = Size Function(
  Pointer<Void> handle,
  Size line,
  Pointer<Uint8> buffer,
  Size bufferSize,
);
typedef FsTextReadLineDart = int Function(
  Pointer<Void> handle,
  int line,
  Pointer<Uint8> buffer,
  int bufferSize,
);
typedef FsTextErrorNative = Pointer<Utf8> Function(Pointer<Void> handle);
typedef FsTextErrorDart = Pointer<Utf8> Function(Pointer<Void> handle);

// ============================================================
// ====================  CORE NATIVE CLASS  ====================
// ============================================================

/// Unified native bindings for the `core` static library.
/// Combines file_ops (file system operations) + fs_text (large text file reader).
class CoreNative {
  static CoreNative? _instance;
  late final DynamicLibrary _lib;

  // ---- file_ops bindings ----
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
  late final JsonRecentDart getRecentFiles;
  late final EncryptDecryptDart encryptFile;
  late final EncryptDecryptDart decryptFile;
  late final JsonPathDart readTextFile;
  late final WriteTextDart writeTextFile;
  late final JsonPathDart readCsvFile;
  late final JsonHexDart readHexChunk;
  late final JsonPathDart readImageAsBase64;
  late final JsonPathDart readBinaryAsBase64;
  // 权限/链接操作
  late final AccessDart access;
  late final ChownDart chown;
  late final ChownDart lchown;
  late final SymlinkDart symlink;
  late final LinkDart link;
  late final JsonPathDart realpath;
  late final JsonPathDart readlink;
  // 文件工具
  late final ChmodDart chmod;
  late final JsonPathDart detectEncoding;
  late final JsonPathDart textStats;
  late final CompareDart compareFiles;
  late final SplitFileDart splitFile;
  late final MergeFilesDart mergeFiles;

  // ---- fs_text bindings ----
  late final FsTextCreateDart _textCreate;
  late final FsTextDestroyDart _textDestroy;
  late final FsTextOpenDart _textOpen;
  late final FsTextCloseDart _textClose;
  late final FsTextIsOpenDart _textIsOpen;
  late final FsTextSizeDart _textSize;
  late final FsTextPathDart _textPath;
  late final FsTextReadDart _textRead;
  late final FsTextLineCountDart _textLineCount;
  late final FsTextReadLineDart _textReadLine;
  late final FsTextErrorDart _textError;

  CoreNative._() {
    _lib = _loadLibrary();
    _bindFileOps();
    _bindFsText();
  }

  factory CoreNative() {
    _instance ??= CoreNative._();
    return _instance!;
  }

  // 静态库直接集成进可执行文件，通过当前进程符号表查找（无需 .so）。
  // Android：core/media 打包为 libfileops.so，通过 dlopen 加载。
  DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) return DynamicLibrary.open('libfileops.so');
    return DynamicLibrary.process();
  }

  void _bindFileOps() {
    listDirectory = _lib.lookupFunction<JsonListDirNative, JsonListDirDart>('fs_list_directory');
    getFileInfo = _lib.lookupFunction<JsonGetInfoNative, JsonGetInfoDart>('fs_get_file_info');
    searchFiles = _lib.lookupFunction<JsonSearchNative, JsonSearchDart>('fs_search_files');
    computeHash = _lib.lookupFunction<JsonHashNative, JsonHashDart>('fs_compute_hash');
    getDiskUsage = _lib.lookupFunction<JsonDiskNative, JsonDiskDart>('fs_get_disk_usage');
    findDuplicates = _lib.lookupFunction<JsonFindNative, JsonFindDart>('fs_find_duplicates');
    findEmptyFiles = _lib.lookupFunction<JsonFindNative, JsonFindDart>('fs_find_empty_files');
    getHomeDir = _lib.lookupFunction<JsonGetStrNative, JsonGetStrDart>('fs_get_home_dir');
    getRootDir = _lib.lookupFunction<JsonGetStrNative, JsonGetStrDart>('fs_get_root_dir');
    freeJson = _lib.lookupFunction<FreeJsonNative, FreeJsonDart>('fs_free_json');
    createDirectory = _lib.lookupFunction<OpWithErrNative, OpWithErrDart>('fs_create_directory');
    createFile = _lib.lookupFunction<OpWithErrNative, OpWithErrDart>('fs_create_file');
    deleteFile = _lib.lookupFunction<OpWithErrNative, OpWithErrDart>('fs_delete_file');
    rename = _lib.lookupFunction<RenameNative, RenameDart>('fs_rename');
    copyFile = _lib.lookupFunction<CopyMoveNative, CopyMoveDart>('fs_copy_file');
    moveFile = _lib.lookupFunction<CopyMoveNative, CopyMoveDart>('fs_move_file');
    exists = _lib.lookupFunction<ExistsNative, ExistsDart>('fs_exists');
    isDirectoryFn = _lib.lookupFunction<ExistsNative, ExistsDart>('fs_is_directory');
    getRecentFiles = _lib.lookupFunction<JsonRecentNative, JsonRecentDart>('fs_get_recent_files');
    encryptFile = _lib.lookupFunction<EncryptDecryptNative, EncryptDecryptDart>('fs_encrypt_file');
    decryptFile = _lib.lookupFunction<EncryptDecryptNative, EncryptDecryptDart>('fs_decrypt_file');
    readTextFile = _lib.lookupFunction<JsonPathNative, JsonPathDart>('fs_read_text_file');
    writeTextFile = _lib.lookupFunction<WriteTextNative, WriteTextDart>('fs_write_text_file');
    readCsvFile = _lib.lookupFunction<JsonPathNative, JsonPathDart>('fs_read_csv_file');
    readHexChunk = _lib.lookupFunction<JsonHexNative, JsonHexDart>('fs_read_hex_chunk');
    readImageAsBase64 = _lib.lookupFunction<JsonPathNative, JsonPathDart>('fs_read_image_as_base64');
    readBinaryAsBase64 = _lib.lookupFunction<JsonPathNative, JsonPathDart>('fs_read_binary_as_base64');
    access = _lib.lookupFunction<AccessNative, AccessDart>('fs_access');
    chown = _lib.lookupFunction<ChownNative, ChownDart>('fs_chown');
    lchown = _lib.lookupFunction<ChownNative, ChownDart>('fs_lchown');
    symlink = _lib.lookupFunction<SymlinkNative, SymlinkDart>('fs_symlink');
    link = _lib.lookupFunction<LinkNative, LinkDart>('fs_link');
    realpath = _lib.lookupFunction<JsonPathNative, JsonPathDart>('fs_realpath');
    readlink = _lib.lookupFunction<JsonPathNative, JsonPathDart>('fs_readlink');
  }

  void _bindFsText() {
    _textCreate = _lib.lookupFunction<FsTextCreateNative, FsTextCreateDart>('fs_text_create');
    _textDestroy = _lib.lookupFunction<FsTextDestroyNative, FsTextDestroyDart>('fs_text_destroy');
    _textOpen = _lib.lookupFunction<FsTextOpenNative, FsTextOpenDart>('fs_text_open');
    _textClose = _lib.lookupFunction<FsTextCloseNative, FsTextCloseDart>('fs_text_close');
    _textIsOpen = _lib.lookupFunction<FsTextIsOpenNative, FsTextIsOpenDart>('fs_text_is_open');
    _textSize = _lib.lookupFunction<FsTextSizeNative, FsTextSizeDart>('fs_text_size');
    _textPath = _lib.lookupFunction<FsTextPathNative, FsTextPathDart>('fs_text_path');
    _textRead = _lib.lookupFunction<FsTextReadNative, FsTextReadDart>('fs_text_read');
    _textLineCount = _lib.lookupFunction<FsTextLineCountNative, FsTextLineCountDart>('fs_text_line_count');
    _textReadLine = _lib.lookupFunction<FsTextReadLineNative, FsTextReadLineDart>('fs_text_read_line');
    _textError = _lib.lookupFunction<FsTextErrorNative, FsTextErrorDart>('fs_text_error');
  }

  // ---- FsText 高层 API（兼容原 lib/ffi/fs_text_ffi.dart 接口） ----

  /// 创建一个新的 FsText 句柄。
  Pointer<Void> fsTextCreate() => _textCreate();

  /// 销毁 FsText 句柄。
  void fsTextDestroy(Pointer<Void> handle) => _textDestroy(handle);

  /// 打开文件，成功返回 0。
  int fsTextOpen(Pointer<Void> handle, Pointer<Utf8> path) =>
      _textOpen(handle, path);

  /// 关闭当前文件。
  void fsTextClose(Pointer<Void> handle) => _textClose(handle);

  /// 是否已打开文件。
  int fsTextIsOpen(Pointer<Void> handle) => _textIsOpen(handle);

  /// 文件大小（字节）。
  int fsTextSize(Pointer<Void> handle) => _textSize(handle);

  /// 当前文件路径。
  Pointer<Utf8> fsTextPath(Pointer<Void> handle) => _textPath(handle);

  /// 读取 [offset, offset+length) 字节到 buffer，返回实际读取字节数。
  int fsTextRead(
    Pointer<Void> handle,
    int offset,
    int length,
    Pointer<Uint8> buffer,
    int bufferSize,
  ) => _textRead(handle, offset, length, buffer, bufferSize);

  /// 行数。
  int fsTextLineCount(Pointer<Void> handle) => _textLineCount(handle);

  /// 读取指定行（0-based）到 buffer，返回实际字节数（不含换行符）。
  int fsTextReadLine(
    Pointer<Void> handle,
    int line,
    Pointer<Uint8> buffer,
    int bufferSize,
  ) => _textReadLine(handle, line, buffer, bufferSize);

  /// 最近一次错误信息。
  Pointer<Utf8> fsTextError(Pointer<Void> handle) => _textError(handle);
}
