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

// char* media_decode_image_buffer(const unsigned char* data, int len)

// char* media_make_thumbnail(const char* path, int max_size)

// char* media_make_video_thumbnail(const char* path, int max_size)
typedef MakeVideoThumbnailNative = Pointer<Utf8> Function(Pointer<Utf8>, Int32);
typedef MakeVideoThumbnailDart = Pointer<Utf8> Function(Pointer<Utf8>, int);

// char* media_epub_extract_text(const char* path)
typedef EpubExtractTextNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef EpubExtractTextDart = Pointer<Utf8> Function(Pointer<Utf8>);

// char* media_epub_list_files(const char* path)
typedef EpubListFilesNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef EpubListFilesDart = Pointer<Utf8> Function(Pointer<Utf8>);

// void* media_video_open(const unsigned char* data, int len)
typedef VideoOpenNative = Pointer<Void> Function(Pointer<Uint8>, Int32);
typedef VideoOpenDart = Pointer<Void> Function(Pointer<Uint8>, int);

// int media_video_next_frame_rgba(void* handle, uint8_t* out, int out_cap, int* out_w, int* out_h, double* out_ts)
typedef VideoNextFrameRgbaNative = Int32 Function(
    Pointer<Void>, Pointer<Uint8>, Int32, Pointer<Int32>, Pointer<Int32>, Pointer<Double>);
typedef VideoNextFrameRgbaDart = int Function(
    Pointer<Void>, Pointer<Uint8>, int, Pointer<Int32>, Pointer<Int32>, Pointer<Double>);

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

  late final MakeVideoThumbnailDart makeVideoThumbnail;
  late final EpubExtractTextDart epubExtractText;
  late final EpubListFilesDart epubListFiles;
  late final VideoOpenDart videoOpen;
  late final VideoNextFrameRgbaDart videoNextFrameRgba;
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
    makeVideoThumbnail = _lib.lookupFunction<MakeVideoThumbnailNative, MakeVideoThumbnailDart>('media_make_video_thumbnail');
    epubExtractText = _lib.lookupFunction<EpubExtractTextNative, EpubExtractTextDart>('media_epub_extract_text');
    epubListFiles = _lib.lookupFunction<EpubListFilesNative, EpubListFilesDart>('media_epub_list_files');
    videoOpen = _lib.lookupFunction<VideoOpenNative, VideoOpenDart>('media_video_open');
    videoNextFrameRgba = _lib.lookupFunction<VideoNextFrameRgbaNative, VideoNextFrameRgbaDart>('media_video_next_frame_rgba');
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

  /// 生成视频封面（返回 base64 + 尺寸 JSON）
  Map<String, dynamic>? makeVideoThumbnailJson(String path, int maxSize) {
    final pp = path.toNativeUtf8();
    try {
      final str = _callJson(() => makeVideoThumbnail(pp, maxSize));
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
  /// 注意：C++ 的 media_video_open 会保存该字节缓冲的指针供后续解码使用，
  /// 因此必须保证缓冲在 handle 存活期间不被释放，并在 closeVideo 时释放。
  final Map<Pointer<Void>, Pointer<Uint8>> _videoBuffers = {};

  // 每句柄的预分配 RGBA 帧缓冲（复用，避免每帧 malloc/JSON/base64 往返）。
  final Map<Pointer<Void>, Pointer<Uint8>> _frameBufs = {};
  final Map<Pointer<Void>, int> _frameBufSizes = {};

  /// 按视频实际分辨率分配复用帧缓冲（w*h*4）。
  void prepareFrameBuffer(Pointer<Void> handle) {
    final info = getVideoInfo(handle);
    final w = (info?['width'] as int?) ?? 0;
    final h = (info?['height'] as int?) ?? 0;
    if (w <= 0 || h <= 0) return;
    final need = w * h * 4;
    if ((_frameBufSizes[handle] ?? 0) >= need) return;
    final old = _frameBufs.remove(handle);
    if (old != null) malloc.free(old);
    _frameBufs[handle] = malloc<Uint8>(need);
    _frameBufSizes[handle] = need;
  }

  /// 解码下一帧为裸 RGBA 字节，直接写入复用缓冲（无 base64/JSON）。
  /// 返回 (bytes, width, height, timestamp)，EOF/错误返回 null。
  ({Uint8List bytes, int width, int height, double timestamp})? nextVideoFrameRgba(
    Pointer<Void> handle,
  ) {
    final wPtr = calloc<Int32>();
    final hPtr = calloc<Int32>();
    final tsPtr = calloc<Double>();
    try {
      final ptr = _frameBufs[handle];
      final cap = _frameBufSizes[handle];
      if (ptr == null || cap == null) return null;
      final ret = videoNextFrameRgba(handle, ptr, cap, wPtr, hPtr, tsPtr);
      if (ret != 1) return null;
      final w = wPtr.value;
      final h = hPtr.value;
      final need = w * h * 4;
      if (w <= 0 || h <= 0 || cap < need) return null;
      return (
        bytes: ptr.asTypedList(need),
        width: w,
        height: h,
        timestamp: tsPtr.value,
      );
    } catch (_) {
      return null;
    } finally {
      calloc.free(wPtr);
      calloc.free(hPtr);
      calloc.free(tsPtr);
    }
  }

  Pointer<Void>? openVideoFromBytes(Uint8List data) {
    final ptr = malloc<Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    final handle = videoOpen(ptr, data.length);
    if (handle == nullptr) {
      malloc.free(ptr);
      return null;
    }
    _videoBuffers[handle] = ptr;
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

  /// 跳转到指定时间戳（秒）
  bool seekVideo(Pointer<Void> handle, double timestamp) {
    return videoSeek(handle, timestamp) == 1;
  }

  /// 关闭视频
  void closeVideo(Pointer<Void> handle) {
    videoClose(handle);
    // 释放与 handle 关联的字节缓冲（C++ 解码期间一直引用它）
    final buf = _videoBuffers.remove(handle);
    if (buf != null) malloc.free(buf);
    final fb = _frameBufs.remove(handle);
    if (fb != null) malloc.free(fb);
    _frameBufSizes.remove(handle);
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
