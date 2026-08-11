import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

//
// =========================
// C 函数定义
// =========================
//

// TextOpsHandle text_ops_create(void)
typedef TextOpsCreateNative = Pointer<Void> Function();
typedef TextOpsCreateDart = Pointer<Void> Function();

// void text_ops_destroy(TextOpsHandle handle)
typedef TextOpsDestroyNative = Void Function(Pointer<Void> handle);

typedef TextOpsDestroyDart = void Function(Pointer<Void> handle);

// int text_ops_open(
//     TextOpsHandle handle,
//     const char* path
// )
typedef TextOpsOpenNative =
    Int32 Function(Pointer<Void> handle, Pointer<Utf8> path);

typedef TextOpsOpenDart =
    int Function(Pointer<Void> handle, Pointer<Utf8> path);

// void text_ops_close(TextOpsHandle handle)
typedef TextOpsCloseNative = Void Function(Pointer<Void> handle);

typedef TextOpsCloseDart = void Function(Pointer<Void> handle);

// int text_ops_is_open(TextOpsHandle handle)
typedef TextOpsIsOpenNative = Int32 Function(Pointer<Void> handle);

typedef TextOpsIsOpenDart = int Function(Pointer<Void> handle);

// size_t text_ops_size(TextOpsHandle handle)
typedef TextOpsSizeNative = Size Function(Pointer<Void> handle);

typedef TextOpsSizeDart = int Function(Pointer<Void> handle);

// const char* text_ops_path(TextOpsHandle handle)
typedef TextOpsPathNative = Pointer<Utf8> Function(Pointer<Void> handle);

typedef TextOpsPathDart = Pointer<Utf8> Function(Pointer<Void> handle);

// size_t text_ops_read(
//     handle,
//     offset,
//     length,
//     buffer,
//     buffer_size
// )
typedef TextOpsReadNative =
    Size Function(
      Pointer<Void> handle,
      Size offset,
      Size length,
      Pointer<Uint8> buffer,
      Size bufferSize,
    );

typedef TextOpsReadDart =
    int Function(
      Pointer<Void> handle,
      int offset,
      int length,
      Pointer<Uint8> buffer,
      int bufferSize,
    );

// size_t text_ops_line_count(...)
typedef TextOpsLineCountNative = Size Function(Pointer<Void> handle);

typedef TextOpsLineCountDart = int Function(Pointer<Void> handle);

// size_t text_ops_read_line(...)
typedef TextOpsReadLineNative =
    Size Function(
      Pointer<Void> handle,
      Size line,
      Pointer<Uint8> buffer,
      Size bufferSize,
    );

typedef TextOpsReadLineDart =
    int Function(
      Pointer<Void> handle,
      int line,
      Pointer<Uint8> buffer,
      int bufferSize,
    );

// const char* text_ops_error(...)
typedef TextOpsErrorNative = Pointer<Utf8> Function(Pointer<Void> handle);

typedef TextOpsErrorDart = Pointer<Utf8> Function(Pointer<Void> handle);

//
// =========================
// Dart 封装
// =========================
//

class TextOps {
  late final DynamicLibrary _library;

  late final TextOpsCreateDart _create;
  late final TextOpsDestroyDart _destroy;
  late final TextOpsOpenDart _open;
  late final TextOpsCloseDart _close;
  late final TextOpsIsOpenDart _isOpen;
  late final TextOpsSizeDart _size;
  late final TextOpsPathDart _path;
  late final TextOpsReadDart _read;
  late final TextOpsLineCountDart _lineCount;
  late final TextOpsReadLineDart _readLine;
  late final TextOpsErrorDart _error;

  Pointer<Void>? _handle;

  TextOps() {
    _library = _loadLibrary();

    _create = _library.lookupFunction<TextOpsCreateNative, TextOpsCreateDart>(
      'text_ops_create',
    );

    _destroy = _library
        .lookupFunction<TextOpsDestroyNative, TextOpsDestroyDart>(
          'text_ops_destroy',
        );

    _open = _library.lookupFunction<TextOpsOpenNative, TextOpsOpenDart>(
      'text_ops_open',
    );

    _close = _library.lookupFunction<TextOpsCloseNative, TextOpsCloseDart>(
      'text_ops_close',
    );

    _isOpen = _library.lookupFunction<TextOpsIsOpenNative, TextOpsIsOpenDart>(
      'text_ops_is_open',
    );

    _size = _library.lookupFunction<TextOpsSizeNative, TextOpsSizeDart>(
      'text_ops_size',
    );

    _path = _library.lookupFunction<TextOpsPathNative, TextOpsPathDart>(
      'text_ops_path',
    );

    _read = _library.lookupFunction<TextOpsReadNative, TextOpsReadDart>(
      'text_ops_read',
    );

    _lineCount = _library
        .lookupFunction<TextOpsLineCountNative, TextOpsLineCountDart>(
          'text_ops_line_count',
        );

    _readLine = _library
        .lookupFunction<TextOpsReadLineNative, TextOpsReadLineDart>(
          'text_ops_read_line',
        );

    _error = _library.lookupFunction<TextOpsErrorNative, TextOpsErrorDart>(
      'text_ops_error',
    );

    _handle = _create();

    if (_handle == nullptr) {
      throw Exception('无法创建 TextOps');
    }
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isLinux) {
      return DynamicLibrary.open('libtext_ops.so');
    }

    if (Platform.isWindows) {
      return DynamicLibrary.open('text_ops.dll');
    }

    if (Platform.isMacOS) {
      return DynamicLibrary.open('libtext_ops.dylib');
    }

    if (Platform.isAndroid) {
      return DynamicLibrary.open('libtext_ops.so');
    }

    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }

    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  Pointer<Void> get handle {
    final handle = _handle;

    if (handle == null || handle == nullptr) {
      throw StateError('TextOps 已经释放');
    }

    return handle;
  }

  void open(String path) {
    final pathPtr = path.toNativeUtf8();

    try {
      final result = _open(handle, pathPtr);

      if (result != 0) {
        throw Exception('打开文件失败: ${error}');
      }
    } finally {
      malloc.free(pathPtr);
    }
  }

  void close() {
    _close(handle);
  }

  bool get isOpen {
    return _isOpen(handle) != 0;
  }

  int get size {
    return _size(handle);
  }

  String get path {
    final ptr = _path(handle);

    if (ptr == nullptr) {
      return '';
    }

    return ptr.toDartString();
  }

  int get lineCount {
    return _lineCount(handle);
  }

  String read({required int offset, required int length}) {
    if (length <= 0) {
      return '';
    }

    final buffer = malloc<Uint8>(length + 1);

    try {
      final count = _read(handle, offset, length, buffer, length + 1);

      if (count == 0) {
        return '';
      }

      return buffer.cast<Utf8>().toDartString(length: count);
    } finally {
      malloc.free(buffer);
    }
  }

  String readLine(int line) {
    /*
     * 第一阶段先分配一个 64KB buffer。
     *
     * 后面可以增加：
     * text_ops_line_length()
     *
     * 来精确分配。
     */
    const bufferSize = 64 * 1024;

    final buffer = malloc<Uint8>(bufferSize);

    try {
      final count = _readLine(handle, line, buffer, bufferSize);

      if (count == 0) {
        return '';
      }

      return buffer.cast<Utf8>().toDartString(length: count);
    } finally {
      malloc.free(buffer);
    }
  }

  String get error {
    final ptr = _error(handle);

    if (ptr == nullptr) {
      return '';
    }

    return ptr.toDartString();
  }

  void dispose() {
    final handle = _handle;

    if (handle == null || handle == nullptr) {
      return;
    }

    _destroy(handle);

    _handle = null;
  }
}
