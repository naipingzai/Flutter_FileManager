// ignore_for_file: non_constant_identifier_names
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'native_library.dart';

// ============================================================
// media 静态库 FFI 绑定
// 静态库直接集成进可执行文件，通过 DynamicLibrary.process() 查找符号
// ============================================================

// char* media_decode_image_file(const char* path)
typedef DecodeImageFileNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef DecodeImageFileDart = Pointer<Utf8> Function(Pointer<Utf8>);

// char* media_decode_image_buffer(const unsigned char* data, int len)
typedef DecodeImageBufferNative = Pointer<Utf8> Function(Pointer<Uint8>, Int32);
typedef DecodeImageBufferDart = Pointer<Utf8> Function(Pointer<Uint8>, int);

// char* media_epub_extract_text(const char* path)
typedef EpubExtractTextNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef EpubExtractTextDart = Pointer<Utf8> Function(Pointer<Utf8>);

// char* media_epub_list_files(const char* path)
typedef EpubListFilesNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef EpubListFilesDart = Pointer<Utf8> Function(Pointer<Utf8>);

// void* media_video_open(const unsigned char* data, int len)
typedef VideoOpenNative = Pointer<Void> Function(Pointer<Uint8>, Int32);
typedef VideoOpenDart = Pointer<Void> Function(Pointer<Uint8>, int);

// int media_video_next_frame(void* handle, char** out_json)
typedef VideoNextFrameNative = Int32 Function(Pointer<Void>, Pointer<Pointer<Utf8>>);
typedef VideoNextFrameDart = int Function(Pointer<Void>, Pointer<Pointer<Utf8>>);

// int media_video_seek(void* handle, double timestamp)
typedef VideoSeekNative = Int32 Function(Pointer<Void>, Double);
typedef VideoSeekDart = int Function(Pointer<Void>, double);

// char* media_video_get_info(void* handle)
typedef VideoGetInfoNative = Pointer<Utf8> Function(Pointer<Void>);
typedef VideoGetInfoDart = Pointer<Utf8> Function(Pointer<Void>);

// void media_video_close(void* handle)
typedef VideoCloseNative = Void Function(Pointer<Void>);
typedef VideoCloseDart = void Function(Pointer<Void>);

// char* media_decode_audio(const unsigned char* data, int len)
typedef DecodeAudioNative = Pointer<Utf8> Function(Pointer<Uint8>, Int32);
typedef DecodeAudioDart = Pointer<Utf8> Function(Pointer<Uint8>, int);

// void media_free_string(char* str)
typedef FreeStringNative = Void Function(Pointer<Utf8>);
typedef FreeStringDart = void Function(Pointer<Utf8>);

// void* media_audio_output_open(int sample_rate, int channels, int bits)
typedef AudioOutOpenNative = Pointer<Void> Function(Int32, Int32, Int32);
typedef AudioOutOpenDart = Pointer<Void> Function(int, int, int);

// int media_audio_output_write(void* handle, const unsigned char* pcm, int len)
typedef AudioOutWriteNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32);
typedef AudioOutWriteDart = int Function(Pointer<Void>, Pointer<Uint8>, int);

// void media_audio_output_stop(void* handle)
typedef AudioOutStopNative = Void Function(Pointer<Void>);
typedef AudioOutStopDart = void Function(Pointer<Void>);

// void media_audio_output_close(void* handle)
typedef AudioOutCloseNative = Void Function(Pointer<Void>);
typedef AudioOutCloseDart = void Function(Pointer<Void>);

/// media 静态库封装（图片/电子书/视频/音频解码）
class MediaNative {
  static MediaNative? _instance;
  late final DynamicLibrary _lib;

  late final DecodeImageFileDart decodeImageFile;
  late final DecodeImageBufferDart decodeImageBuffer;
  late final EpubExtractTextDart epubExtractText;
  late final EpubListFilesDart epubListFiles;
  late final VideoOpenDart videoOpen;
  late final VideoNextFrameDart videoNextFrame;
  late final VideoSeekDart videoSeek;
  late final VideoGetInfoDart videoGetInfo;
  late final VideoCloseDart videoClose;
  late final DecodeAudioDart decodeAudio;
  late final FreeStringDart freeString;
  // 音频输出（平台层）
  late final AudioOutOpenDart audioOutOpen;
  late final AudioOutWriteDart audioOutWrite;
  late final AudioOutStopDart audioOutStop;
  late final AudioOutCloseDart audioOutClose;

  MediaNative._() {
    _lib = loadNativeLibrary();
    _bindFunctions();
  }

  factory MediaNative() {
    _instance ??= MediaNative._();
    return _instance!;
  }

  void _bindFunctions() {
    decodeImageFile = _lib.lookupFunction<DecodeImageFileNative, DecodeImageFileDart>('media_decode_image_file');
    decodeImageBuffer = _lib.lookupFunction<DecodeImageBufferNative, DecodeImageBufferDart>('media_decode_image_buffer');
    epubExtractText = _lib.lookupFunction<EpubExtractTextNative, EpubExtractTextDart>('media_epub_extract_text');
    epubListFiles = _lib.lookupFunction<EpubListFilesNative, EpubListFilesDart>('media_epub_list_files');
    videoOpen = _lib.lookupFunction<VideoOpenNative, VideoOpenDart>('media_video_open');
    videoNextFrame = _lib.lookupFunction<VideoNextFrameNative, VideoNextFrameDart>('media_video_next_frame');
    videoSeek = _lib.lookupFunction<VideoSeekNative, VideoSeekDart>('media_video_seek');
    videoGetInfo = _lib.lookupFunction<VideoGetInfoNative, VideoGetInfoDart>('media_video_get_info');
    videoClose = _lib.lookupFunction<VideoCloseNative, VideoCloseDart>('media_video_close');
    decodeAudio = _lib.lookupFunction<DecodeAudioNative, DecodeAudioDart>('media_decode_audio');
    freeString = _lib.lookupFunction<FreeStringNative, FreeStringDart>('media_free_string');
    audioOutOpen = _lib.lookupFunction<AudioOutOpenNative, AudioOutOpenDart>('media_audio_output_open');
    audioOutWrite = _lib.lookupFunction<AudioOutWriteNative, AudioOutWriteDart>('media_audio_output_write');
    audioOutStop = _lib.lookupFunction<AudioOutStopNative, AudioOutStopDart>('media_audio_output_stop');
    audioOutClose = _lib.lookupFunction<AudioOutCloseNative, AudioOutCloseDart>('media_audio_output_close');
  }

  String _callJson(Pointer<Utf8> Function() fn) {
    final ptr = fn();
    final str = ptr.toDartString();
    freeString(ptr);
    return str;
  }

  /// 解码图片文件为 RGBA（返回 base64 + 尺寸 JSON）
  Map<String, dynamic>? decodeImageFileJson(String path) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => decodeImageFile(pp));
      return jsonDecode(str) as Map<String, dynamic>?;
    } finally {
      malloc.free(pp);
    }
  }

  /// 提取 EPUB 正文
  String? extractEbookText(String path) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => epubExtractText(pp));
      final j = jsonDecode(str) as Map<String, dynamic>;
      return j['text'] as String?;
    } finally {
      malloc.free(pp);
    }
  }

  // ---------- 视频操作（FFmpeg） ----------

  /// 从文件字节打开视频，返回 handle（null 表示失败）
  Pointer<Void>? openVideoFromBytes(Uint8List data) {
    final ptr = malloc<Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    final handle = videoOpen(ptr, data.length);
    malloc.free(ptr);
    if (handle == nullptr) return null;
    return handle;
  }

  /// 从文件路径读取字节并打开视频
  Pointer<Void>? openVideo(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    final data = file.readAsBytesSync();
    return openVideoFromBytes(data);
  }

  /// 获取视频信息 JSON（width, height, duration, fps）
  Map<String, dynamic>? getVideoInfo(Pointer<Void> handle) {
    final ptr = videoGetInfo(handle);
    final str = ptr.toDartString();
    freeString(ptr);
    final j = jsonDecode(str) as Map<String, dynamic>;
    if (j['error'] != null && (j['error'] as String).isNotEmpty) return null;
    return j;
  }

  /// 解码下一帧，返回 JSON（base64, width, height, timestamp）
  /// 返回 null 表示 EOF 或错误
  Map<String, dynamic>? nextVideoFrame(Pointer<Void> handle) {
    final outPtr = calloc<Pointer<Utf8>>();
    try {
      final ret = videoNextFrame(handle, outPtr);
      if (ret <= 0) return null; // 0=EOF, -1=error
      final ptr = outPtr.value;
      if (ptr == nullptr) return null;
      final str = ptr.toDartString();
      freeString(ptr);
      final j = jsonDecode(str) as Map<String, dynamic>;
      if (j['error'] != null && (j['error'] as String).isNotEmpty) return null;
      return j;
    } catch (_) {
      return null;
    } finally {
      calloc.free(outPtr);
    }
  }

  /// 跳转到指定时间戳（秒）
  bool seekVideo(Pointer<Void> handle, double timestamp) {
    return videoSeek(handle, timestamp) == 1;
  }

  /// 关闭视频
  void closeVideo(Pointer<Void> handle) {
    videoClose(handle);
  }

  // ---------- 音频操作（FFmpeg） ----------

  /// 解码音频文件，返回 JSON（base64 完整 PCM, sample_rate, channels, bits, length）
  Map<String, dynamic>? decodeAudioFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    final data = file.readAsBytesSync();
    final ptr = malloc<Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    try {
      final retPtr = decodeAudio(ptr, data.length);
      final str = retPtr.toDartString();
      freeString(retPtr);
      final j = jsonDecode(str) as Map<String, dynamic>;
      if (j['error'] != null && (j['error'] as String).isNotEmpty) return null;
      return j;
    } catch (_) {
      return null;
    } finally {
      malloc.free(ptr);
    }
  }

  // ---------- 音频输出（平台层） ----------

  Pointer<Void>? audioOutputOpen(int sampleRate, int channels, int bits) {
    final handle = audioOutOpen(sampleRate, channels, bits);
    if (handle == nullptr) return null;
    return handle;
  }

  int audioOutputWrite(Pointer<Void> handle, Pointer<Uint8> pcm, int len) =>
      audioOutWrite(handle, pcm, len);

  void audioOutputStop(Pointer<Void> handle) => audioOutStop(handle);

  void audioOutputClose(Pointer<Void> handle) => audioOutClose(handle);
}
