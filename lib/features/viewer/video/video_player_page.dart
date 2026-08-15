import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';

/// 视频播放器（APP 内部渲染，使用 media 静态库 FFmpeg 解码）
///
/// 关键实现要点：
/// 1. 用一个 Future-based 单帧解码队列，避免 Timer 触发多个并发解码。
/// 2. 用 [Completer] 跟踪当前解码任务，pause 时取消未完成的任务。
/// 3. 首帧渲染完成后立即 [setState]，确保 UI 立即更新。
class VideoPlayerPage extends StatefulWidget {
  final String path;
  const VideoPlayerPage({super.key, required this.path});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  Pointer<Void>? _handle;
  ui.Image? _currentFrame;
  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';
  bool _playing = false;
  bool _eof = false;

  // 视频信息
  double _duration = 0;
  double _fps = 25;
  double _currentTime = 0;

  // 帧解码串行化
  bool _decoding = false;
  Timer? _timer;
  // dispose 后强制退出 timer 回调
  bool _disposed = false;

  // 已入队待释放的旧帧。ui.Image 必须在不再被 RawImage 绘制后才能 dispose，
  // 否则会触发 “disposed image still in use” 原生崩溃。这里用身份集合保证每帧只释放一次。
  final Set<ui.Image> _pendingDispose = {};

  // 音频播放（复用音频播放器模式：完整解码为 PCM + 平台音频输出 + Timer 分块推送）
  Uint8List? _audioPcm;
  Pointer<Void>? _audioOutput;
  int _audioSampleRate = 0;
  int _audioChannels = 0;
  int _audioPos = 0; // 已播放音频字节游标
  Timer? _audioTimer;
  int _audioRampBytes = 0; // seek 后淡入渐变字节数，避免爆破音

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final fs = FileService();
    final handle = fs.openVideo(widget.path);
    if (handle == null) {
      setState(() {
        _loading = false;
        _error = true;
        _errorMsg = '无法打开视频文件';
      });
      return;
    }
    _handle = handle;
    final info = fs.getVideoInfo(handle);
    if (info != null) {
      _duration = (info['duration'] ?? 0).toDouble();
      _fps = (info['fps'] ?? 25).toDouble();
      if (_fps <= 0) _fps = 25;
    }
    // 预分配 RGBA 帧缓冲，供 nextVideoFrameRgba 复用（避免每帧 base64/JSON 往返）
    fs.prepareVideoFrameBuffer(handle);
    // 解码音轨 + 打开音频输出（无音轨则跳过，不影响视频）
    _initAudio();
    setState(() => _loading = false);
    // 自动播放（用 post-frame 避免 setState 期间启动 timer）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _handle != null) _play();
    });
  }

  void _initAudio() {
    try {
      final fs = FileService();
      final result = fs.decodeAudio(widget.path);
      final b64 = result?['base64'] as String?;
      if (result == null || b64 == null || b64.isEmpty) return;
      final rate = (result['sample_rate'] ?? 0) as int;
      final ch = (result['channels'] ?? 0) as int;
      final pcm = base64Decode(b64);
      if (rate <= 0 || ch <= 0 || pcm.isEmpty) return;
      final out = fs.audioOutputOpen(rate, ch, 16);
      if (out == null) return;
      _audioPcm = pcm;
      _audioSampleRate = rate;
      _audioChannels = ch;
      _audioPos = 0;
      _audioOutput = out;
    } catch (_) {
      // 音频解码失败不影响视频播放
      _audioPcm = null;
    }
  }

  /// 每 100ms 把 PCM 分块送入音频输出（与音频播放器一致）。
  void _pumpAudio() {
    if (_disposed || _audioPcm == null || _audioOutput == null || !_playing) return;
    final pcm = _audioPcm!;
    final frameBytes = _audioSampleRate * _audioChannels * 2 ~/ 10;
    if (_audioPos >= pcm.length) {
      _stopAudio();
      return;
    }
    var chunk = frameBytes;
    if (_audioPos + chunk > pcm.length) chunk = pcm.length - _audioPos;
    final ptr = malloc<Uint8>(chunk);
    try {
      final data = pcm.sublist(_audioPos, _audioPos + chunk);
      // seek 后对开头做线性淡入，消除切到新波形位置的爆破音
      if (_audioRampBytes > 0) {
        final ramp = _audioRampBytes < chunk ? _audioRampBytes : chunk;
        for (var i = 0; i < ramp; i += 2) {
          final gain = i / ramp;
          final lo = data[i];
          final hi = data[i + 1];
          var v = (lo | (hi << 8)).toSigned(16);
          v = (v * gain).round();
          data[i] = v & 0xff;
          data[i + 1] = (v >> 8) & 0xff;
        }
        _audioRampBytes = 0;
      }
      ptr.asTypedList(chunk).setAll(0, data);
      final written = FileService().audioOutputWrite(_audioOutput!, ptr, chunk);
      if (written > 0) {
        _audioPos += written;
      }
    } catch (_) {
      _stopAudio();
    } finally {
      malloc.free(ptr);
    }
  }

  void _stopAudio() {
    _audioTimer?.cancel();
    _audioTimer = null;
    if (_audioOutput != null) {
      FileService().audioOutputStop(_audioOutput!);
    }
  }

  /// 延迟到当前帧绘制结束后再释放旧帧，避免 RawImage 仍在绘制时 dispose 导致崩溃。
  /// 用身份集合去重，保证每个 ui.Image 恰好释放一次。
  void _scheduleFrameDispose(ui.Image? img) {
    if (img == null) return;
    if (!_pendingDispose.add(img)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingDispose.remove(img);
      if (_disposed) {
        img.dispose();
        return;
      }
      // 仅当该帧不再作为当前帧被显示时才释放
      if (identical(img, _currentFrame)) return;
      img.dispose();
    });
  }

  void _play() {
    if (_playing || _handle == null || _eof) return;
    setState(() => _playing = true);
    final intervalMs = (1000 / _fps).round().clamp(10, 1000);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) => _nextFrameSafe());
    // 启动音频播放（若有音轨）
    if (_audioOutput != null && _audioPcm != null) {
      _audioTimer?.cancel();
      _audioTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => _pumpAudio());
    }
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    _stopAudio();
    if (_playing) setState(() => _playing = false);
  }

  /// 安全入口：避免上一帧解码还没完成就启动下一帧。
  void _nextFrameSafe() {
    if (_decoding) return;
    _decoding = true;
    _nextFrame().whenComplete(() {
      _decoding = false;
    });
  }

  Future<void> _nextFrame() async {
    if (_disposed || _handle == null || !_playing || !mounted) return;
    final fs = FileService();
    final frame = fs.nextVideoFrameRgba(_handle!);
    if (_disposed || _handle == null) return;
    if (frame == null) {
      // EOF 或错误
      _pause();
      if (mounted) setState(() => _eof = true);
      return;
    }
    final w = frame.width;
    final h = frame.height;
    final ts = frame.timestamp;
    final bytes = frame.bytes;
    if (w <= 0 || h <= 0 || bytes.length != w * h * 4) return;

    // 释放上一帧（延迟到当前帧绘制完成后，避免 RawImage 仍在绘制时释放崩溃）
    final oldFrame = _currentFrame;

    final completer = Completer<ui.Image>();
    try {
      ui.decodeImageFromPixels(
        bytes,
        w,
        h,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
    } catch (_) {
      return; // 同步参数错误
    }
    try {
      final img = await completer.future;
      if (_disposed || !mounted) {
        img.dispose();
        return;
      }
      setState(() {
        _currentFrame = img;
        _currentTime = ts;
      });
      // 旧帧已替换出渲染树，可在帧绘制后安全释放
      _scheduleFrameDispose(oldFrame);
    } catch (_) {
      // 图片解码失败，跳过
    }
  }

  void _seek(double seconds) {
    if (_handle == null) return;
    seconds = seconds.clamp(0.0, _duration > 0 ? _duration : seconds);
    final fs = FileService();
    fs.seekVideo(_handle!, seconds);
    // 同步音频游标到对应位置，并对新起点做淡入（避免拖动反复 stop/restart 爆破音）
    if (_audioPcm != null && _audioSampleRate > 0 && _audioChannels > 0) {
      _audioPos = (seconds * _audioSampleRate * _audioChannels * 2).round();
      if (_audioPos > _audioPcm!.length) _audioPos = _audioPcm!.length;
      _audioRampBytes = _audioSampleRate * _audioChannels * 2 ~/ 100; // ~10ms
    }
    setState(() {
      _currentTime = seconds;
      _eof = false;
    });
    // 立即解码一帧作为预览
    _nextFrameSafe();
  }

  String _formatTime(double seconds) {
    final m = (seconds / 60).floor();
    final s = (seconds % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    // 关键：在 dispose 时设标记，让 timer 回调退出
    _disposed = true;
    _timer?.cancel();
    _audioTimer?.cancel();
    _audioTimer = null;
    final out = _audioOutput;
    _audioOutput = null;
    if (out != null) {
      FileService().audioOutputClose(out);
    }
    final h = _handle;
    _handle = null;
    if (h != null) {
      FileService().closeVideo(h);
    }
    _currentFrame?.dispose();
    _currentFrame = null;
    for (final img in _pendingDispose) {
      img.dispose();
    }
    _pendingDispose.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = FileService.getFileName(widget.path);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        title: Text(name, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMsg.isEmpty ? '无法打开视频' : _errorMsg,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                )
              : _buildPlayer(),
    );
  }

  Widget _buildPlayer() {
    return Column(
      children: [
        // 帧显示
        Expanded(
          child: Center(
            child: _currentFrame != null
                ? RawImage(image: _currentFrame, fit: BoxFit.contain)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.movie, size: 64, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        '解码中...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
          ),
        ),
        // 控制栏
        Container(
          color: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              Row(
                children: [
                  Text(
                    _formatTime(_currentTime),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Expanded(
                    child: Slider(
                      value: _duration > 0
                          ? (_currentTime / _duration).clamp(0.0, 1.0)
                          : 0,
                      onChanged: (v) {
                        if (_duration > 0) _seek(v * _duration);
                      },
                      activeColor: Colors.blue,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Text(
                    _formatTime(_duration),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
              // 播放控制
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: Colors.white),
                    onPressed: _handle == null
                        ? null
                        : () => _seek(
                            (_currentTime - 10)
                                .clamp(0, _duration > 0 ? _duration : _currentTime),
                          ),
                  ),
                  IconButton(
                    icon: Icon(
                      _eof
                          ? Icons.replay
                          : (_playing ? Icons.pause : Icons.play_arrow),
                      color: Colors.white,
                      size: 48,
                    ),
                    onPressed: _handle == null
                        ? null
                        : () {
                            if (_eof) {
                              _seek(0);
                              setState(() {});
                            } else if (_playing) {
                              _pause();
                            } else {
                              _play();
                            }
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10, color: Colors.white),
                    onPressed: _handle == null
                        ? null
                        : () => _seek(
                            (_currentTime + 10).clamp(
                              0,
                              _duration > 0 ? _duration : _currentTime,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
