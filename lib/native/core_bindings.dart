// ignore_for_file: non_constant_identifier_names
//
// core_bindings - Dart FFI bindings for native core libraries
// (file 模块 + text 模块，system 模块单独绑定)
//
// 通过 Dart FFI 调用 native modules 静态库。
// 平台差异由 C++ 层处理，Dart 不调用 Platform.isXxx。
// 原生库统一由 native_library.dart 加载（不涉及任何平台判断）。

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'native_library.dart';

// ============================================================
// file 模块 FFI bindings
// ============================================================

typedef FileJsonListDirNative = Pointer<Utf8> Function(Pointer<Utf8>, Int32);
typedef FileJsonListDirDart = Pointer<Utf8> Function(Pointer<Utf8>, int);
typedef FileJsonGetInfoNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef FileJsonGetInfoDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef FileJsonSearchNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef FileJsonSearchDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, int);
typedef FileJsonHashNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef FileJsonHashDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef FileJsonDiskNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef FileJsonDiskDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef FileJsonFindNative = Pointer<Utf8> Function(Pointer<Utf8>, Int32);
typedef FileJsonFindDart = Pointer<Utf8> Function(Pointer<Utf8>, int);
typedef FileJsonGetStrNative = Pointer<Utf8> Function();
typedef FileJsonGetStrDart = Pointer<Utf8> Function();
typedef FileFreeJsonNative = Void Function(Pointer<Utf8>);
typedef FileFreeJsonDart = void Function(Pointer<Utf8>);
typedef FileOpWithErrNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef FileOpWithErrDart = int Function(Pointer<Utf8>, Pointer<Utf8>, int);
typedef FileRenameNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef FileRenameDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef FileCopyMoveNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef FileCopyMoveDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef FileExistsNative = Int32 Function(Pointer<Utf8>);
typedef FileExistsDart = int Function(Pointer<Utf8>);
typedef FileJsonRecentNative = Pointer<Utf8> Function(Pointer<Utf8>, Int32, Int32);
typedef FileJsonRecentDart = Pointer<Utf8> Function(Pointer<Utf8>, int, int);
typedef FileEncryptDecryptNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef FileEncryptDecryptDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef FileJsonPathNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef FileJsonPathDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef FileWriteTextNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef FileWriteTextDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef FileJsonHexNative = Pointer<Utf8> Function(Pointer<Utf8>, Int64, Int32);
typedef FileJsonHexDart = Pointer<Utf8> Function(Pointer<Utf8>, int, int);
typedef FileAccessNative = Int32 Function(Pointer<Utf8>, Int32);
typedef FileAccessDart = int Function(Pointer<Utf8>, int);
typedef FileChownNative = Int32 Function(Pointer<Utf8>, Uint32, Uint32, Pointer<Utf8>, Int32);
typedef FileChownDart = int Function(Pointer<Utf8>, int, int, Pointer<Utf8>, int);
typedef FileSymlinkNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef FileSymlinkDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef FileLinkNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef FileLinkDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);
typedef FileChmodNative = Int32 Function(Pointer<Utf8>, Uint32, Pointer<Utf8>, Int32);
typedef FileChmodDart = int Function(Pointer<Utf8>, int, Pointer<Utf8>, int);
typedef FileCompareNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef FileCompareDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef FileSplitFileNative = Int32 Function(Pointer<Utf8>, Int64, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef FileSplitFileDart = int Function(Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>, int);
typedef FileMergeFilesNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef FileMergeFilesDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int);

// ============================================================
// text 模块 FFI bindings
// ============================================================

typedef TextCreateNative = Pointer<Void> Function();
typedef TextCreateDart = Pointer<Void> Function();
typedef TextDestroyNative = Void Function(Pointer<Void> handle);
typedef TextDestroyDart = void Function(Pointer<Void> handle);
typedef TextOpenNative = Int32 Function(Pointer<Void> handle, Pointer<Utf8> path);
typedef TextOpenDart = int Function(Pointer<Void> handle, Pointer<Utf8> path);
typedef TextCloseNative = Void Function(Pointer<Void> handle);
typedef TextCloseDart = void Function(Pointer<Void> handle);
typedef TextIsOpenNative = Int32 Function(Pointer<Void> handle);
typedef TextIsOpenDart = int Function(Pointer<Void> handle);
typedef TextSizeNative = Size Function(Pointer<Void> handle);
typedef TextSizeDart = int Function(Pointer<Void> handle);
typedef TextPathNative = Pointer<Utf8> Function(Pointer<Void> handle);
typedef TextPathDart = Pointer<Utf8> Function(Pointer<Void> handle);
typedef TextReadNative = Size Function(
  Pointer<Void> handle,
  Size offset,
  Size length,
  Pointer<Uint8> buffer,
  Size bufferSize,
);
typedef TextReadDart = int Function(
  Pointer<Void> handle,
  int offset,
  int length,
  Pointer<Uint8> buffer,
  int bufferSize,
);
typedef TextLineCountNative = Size Function(Pointer<Void> handle);
typedef TextLineCountDart = int Function(Pointer<Void> handle);
typedef TextReadLineNative = Size Function(
  Pointer<Void> handle,
  Size line,
  Pointer<Uint8> buffer,
  Size bufferSize,
);
typedef TextReadLineDart = int Function(
  Pointer<Void> handle,
  int line,
  Pointer<Uint8> buffer,
  int bufferSize,
);
typedef TextErrorNative = Pointer<Utf8> Function(Pointer<Void> handle);
typedef TextErrorDart = Pointer<Utf8> Function(Pointer<Void> handle);

// ============================================================
// CoreNative 绑定类
// ============================================================

/// Unified native bindings for the file + text modules.
class CoreNative {
  static CoreNative? _instance;
  late final DynamicLibrary _lib;

  // file 模块
  late final FileJsonListDirDart listDirectory;
  late final FileJsonGetInfoDart getFileInfo;
  late final FileJsonSearchDart searchFiles;
  late final FileJsonHashDart computeHash;
  late final FileJsonDiskDart getDiskUsage;
  late final FileJsonFindDart findDuplicates;
  late final FileJsonFindDart findEmptyFiles;
  late final FileJsonGetStrDart getHomeDir;
  late final FileJsonGetStrDart getRootDir;
  late final FileFreeJsonDart freeJson;
  late final FileOpWithErrDart createDirectory;
  late final FileOpWithErrDart createFile;
  late final FileOpWithErrDart deleteFile;
  late final FileRenameDart rename;
  late final FileCopyMoveDart copyFile;
  late final FileCopyMoveDart moveFile;
  late final FileExistsDart exists;
  late final FileExistsDart isDirectoryFn;
  late final FileJsonRecentDart getRecentFiles;
  late final FileEncryptDecryptDart encryptFile;
  late final FileEncryptDecryptDart decryptFile;
  late final FileJsonPathDart readTextFile;
  late final FileWriteTextDart writeTextFile;
  late final FileJsonPathDart readCsvFile;
  late final FileJsonHexDart readHexChunk;
  late final FileJsonPathDart readImageAsBase64;
  late final FileJsonPathDart readBinaryAsBase64;
  late final FileAccessDart access;
  late final FileChownDart chown;
  late final FileChownDart lchown;
  late final FileSymlinkDart symlink;
  late final FileLinkDart link;
  late final FileJsonPathDart realpath;
  late final FileJsonPathDart readlink;
  late final FileChmodDart chmod;
  late final FileJsonPathDart detectEncoding;
  late final FileJsonPathDart textStats;
  late final FileCompareDart compareFiles;
  late final FileSplitFileDart splitFile;
  late final FileMergeFilesDart mergeFiles;

  // text 模块
  late final TextCreateDart _textCreate;
  late final TextDestroyDart _textDestroy;
  late final TextOpenDart _textOpen;
  late final TextCloseDart _textClose;
  late final TextIsOpenDart _textIsOpen;
  late final TextSizeDart _textSize;
  late final TextPathDart _textPath;
  late final TextReadDart _textRead;
  late final TextLineCountDart _textLineCount;
  late final TextReadLineDart _textReadLine;
  late final TextErrorDart _textError;

  CoreNative._() {
    _lib = _loadLibrary();
    _bindFileModule();
    _bindTextModule();
  }

  factory CoreNative() {
    _instance ??= CoreNative._();
    return _instance!;
  }

  DynamicLibrary _loadLibrary() {
    return loadNativeLibrary();
  }

  void _bindFileModule() {
    listDirectory = _lib.lookupFunction<FileJsonListDirNative, FileJsonListDirDart>('file_list_directory');
    getFileInfo = _lib.lookupFunction<FileJsonGetInfoNative, FileJsonGetInfoDart>('file_get_file_info');
    searchFiles = _lib.lookupFunction<FileJsonSearchNative, FileJsonSearchDart>('file_search_files');
    computeHash = _lib.lookupFunction<FileJsonHashNative, FileJsonHashDart>('file_compute_hash');
    getDiskUsage = _lib.lookupFunction<FileJsonDiskNative, FileJsonDiskDart>('file_get_disk_usage');
    findDuplicates = _lib.lookupFunction<FileJsonFindNative, FileJsonFindDart>('file_find_duplicates');
    findEmptyFiles = _lib.lookupFunction<FileJsonFindNative, FileJsonFindDart>('file_find_empty_files');
    getHomeDir = _lib.lookupFunction<FileJsonGetStrNative, FileJsonGetStrDart>('file_get_home_dir');
    getRootDir = _lib.lookupFunction<FileJsonGetStrNative, FileJsonGetStrDart>('file_get_root_dir');
    freeJson = _lib.lookupFunction<FileFreeJsonNative, FileFreeJsonDart>('file_free_json');
    createDirectory = _lib.lookupFunction<FileOpWithErrNative, FileOpWithErrDart>('file_create_directory');
    createFile = _lib.lookupFunction<FileOpWithErrNative, FileOpWithErrDart>('file_create_file');
    deleteFile = _lib.lookupFunction<FileOpWithErrNative, FileOpWithErrDart>('file_delete_file');
    rename = _lib.lookupFunction<FileRenameNative, FileRenameDart>('file_rename');
    copyFile = _lib.lookupFunction<FileCopyMoveNative, FileCopyMoveDart>('file_copy_file');
    moveFile = _lib.lookupFunction<FileCopyMoveNative, FileCopyMoveDart>('file_move_file');
    exists = _lib.lookupFunction<FileExistsNative, FileExistsDart>('file_exists');
    isDirectoryFn = _lib.lookupFunction<FileExistsNative, FileExistsDart>('file_is_directory');
    getRecentFiles = _lib.lookupFunction<FileJsonRecentNative, FileJsonRecentDart>('file_get_recent_files');
    encryptFile = _lib.lookupFunction<FileEncryptDecryptNative, FileEncryptDecryptDart>('file_encrypt_file');
    decryptFile = _lib.lookupFunction<FileEncryptDecryptNative, FileEncryptDecryptDart>('file_decrypt_file');
    readTextFile = _lib.lookupFunction<FileJsonPathNative, FileJsonPathDart>('file_read_text_file');
    writeTextFile = _lib.lookupFunction<FileWriteTextNative, FileWriteTextDart>('file_write_text_file');
    readCsvFile = _lib.lookupFunction<FileJsonPathNative, FileJsonPathDart>('file_read_csv_file');
    readHexChunk = _lib.lookupFunction<FileJsonHexNative, FileJsonHexDart>('file_read_hex_chunk');
    readImageAsBase64 = _lib.lookupFunction<FileJsonPathNative, FileJsonPathDart>('file_read_image_as_base64');
    readBinaryAsBase64 = _lib.lookupFunction<FileJsonPathNative, FileJsonPathDart>('file_read_binary_as_base64');
    access = _lib.lookupFunction<FileAccessNative, FileAccessDart>('file_access');
    chown = _lib.lookupFunction<FileChownNative, FileChownDart>('file_chown');
    lchown = _lib.lookupFunction<FileChownNative, FileChownDart>('file_lchown');
    symlink = _lib.lookupFunction<FileSymlinkNative, FileSymlinkDart>('file_symlink');
    link = _lib.lookupFunction<FileLinkNative, FileLinkDart>('file_link');
    realpath = _lib.lookupFunction<FileJsonPathNative, FileJsonPathDart>('file_realpath');
    readlink = _lib.lookupFunction<FileJsonPathNative, FileJsonPathDart>('file_readlink');
    chmod = _lib.lookupFunction<FileChmodNative, FileChmodDart>('file_chmod');
    detectEncoding = _lib.lookupFunction<FileJsonPathNative, FileJsonPathDart>('file_detect_encoding');
    textStats = _lib.lookupFunction<FileJsonPathNative, FileJsonPathDart>('file_text_stats');
    compareFiles = _lib.lookupFunction<FileCompareNative, FileCompareDart>('file_compare_files');
    splitFile = _lib.lookupFunction<FileSplitFileNative, FileSplitFileDart>('file_split_file');
    mergeFiles = _lib.lookupFunction<FileMergeFilesNative, FileMergeFilesDart>('file_merge_files');
  }

  void _bindTextModule() {
    _textCreate = _lib.lookupFunction<TextCreateNative, TextCreateDart>('text_create');
    _textDestroy = _lib.lookupFunction<TextDestroyNative, TextDestroyDart>('text_destroy');
    _textOpen = _lib.lookupFunction<TextOpenNative, TextOpenDart>('text_open');
    _textClose = _lib.lookupFunction<TextCloseNative, TextCloseDart>('text_close');
    _textIsOpen = _lib.lookupFunction<TextIsOpenNative, TextIsOpenDart>('text_is_open');
    _textSize = _lib.lookupFunction<TextSizeNative, TextSizeDart>('text_size');
    _textPath = _lib.lookupFunction<TextPathNative, TextPathDart>('text_path');
    _textRead = _lib.lookupFunction<TextReadNative, TextReadDart>('text_read');
    _textLineCount = _lib.lookupFunction<TextLineCountNative, TextLineCountDart>('text_line_count');
    _textReadLine = _lib.lookupFunction<TextReadLineNative, TextReadLineDart>('text_read_line');
    _textError = _lib.lookupFunction<TextErrorNative, TextErrorDart>('text_error');
  }

  // ---- Text 模块高层 API（公开） ----

  Pointer<Void> textCreate() => _textCreate();
  void textDestroy(Pointer<Void> handle) => _textDestroy(handle);
  int textOpen(Pointer<Void> handle, Pointer<Utf8> path) => _textOpen(handle, path);
  void textClose(Pointer<Void> handle) => _textClose(handle);
  int textIsOpen(Pointer<Void> handle) => _textIsOpen(handle);
  int textSize(Pointer<Void> handle) => _textSize(handle);
  Pointer<Utf8> textPath(Pointer<Void> handle) => _textPath(handle);
  int textRead(Pointer<Void> handle, int offset, int length,
      Pointer<Uint8> buffer, int bufferSize) =>
      _textRead(handle, offset, length, buffer, bufferSize);
  int textLineCount(Pointer<Void> handle) => _textLineCount(handle);
  int textReadLine(Pointer<Void> handle, int line,
      Pointer<Uint8> buffer, int bufferSize) =>
      _textReadLine(handle, line, buffer, bufferSize);
  Pointer<Utf8> textError(Pointer<Void> handle) => _textError(handle);
}
