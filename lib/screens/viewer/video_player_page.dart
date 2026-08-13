import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../services/file_service.dart';

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
  int _width = 0;
  int _height = 0;
  double _duration = 0;
  double _fps = 25;
  double _currentTime = 0;

  // 帧解码串行化
  bool _decoding = false;
  Timer? _timer;
  // dispose 后强制退出 timer 回调
  bool _disposed = false;

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
      _width = (info['width'] ?? 0) as int;
      _height = (info['height'] ?? 0) as int;
      _duration = (info['duration'] ?? 0).toDouble();
      _fps = (info['fps'] ?? 25).toDouble();
      if (_fps <= 0) _fps = 25;
    }
    setState(() => _loading = false);
    // 自动播放（用 post-frame 避免 setState 期间启动 timer）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _handle != null) _play();
    });
  }

  void _play() {
    if (_playing || _handle == null || _eof) return;
    setState(() => _playing = true);
    final intervalMs = (1000 / _fps).round().clamp(10, 1000);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) => _nextFrameSafe());
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
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
    final frame = fs.nextVideoFrame(_handle!);
    if (_disposed || _handle == null) return;
    if (frame == null) {
      // EOF 或错误
      _pause();
      if (mounted) setState(() => _eof = true);
      return;
    }
    final b64 = frame['base64'] as String?;
    if (b64 == null || b64.isEmpty) {
      // 空帧，跳过（继续播放）
      return;
    }
    final w = (frame['width'] as int?) ?? _width;
    final h = (frame['height'] as int?) ?? _height;
    final ts = (frame['timestamp'] ?? _currentTime).toDouble();

    final Uint8List bytes;
    try {
      bytes = base64Decode(b64);
    } catch (_) {
      return; // 解码失败，跳过
    }

    // 释放上一帧
    final oldFrame = _currentFrame;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      w,
      h,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    try {
      final img = await completer.future;
      if (_disposed || !mounted) {
        img.dispose();
        return;
      }
      // 重要：先 dispose 旧帧，再 setState 设置新帧。
      // 在 setState 内部调用 dispose 可能导致当前帧还未渲染就被释放，引发崩溃。
      if (oldFrame != null) oldFrame.dispose();
      setState(() {
        _currentFrame = img;
        _currentTime = ts;
      });
    } catch (_) {
      // 图片解码失败，跳过
    }
  }

  void _seek(double seconds) {
    if (_handle == null) return;
    seconds = seconds.clamp(0.0, _duration > 0 ? _duration : seconds);
    final fs = FileService();
    fs.seekVideo(_handle!, seconds);
    setState(() {
      _currentTime = seconds;
      _eof = false;
    });
    // 立即解码一帧作为预览
    _nextFrameSafe();
    if (_playing) {
      _pause();
      _play();
    }
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
    final h = _handle;
    _handle = null;
    if (h != null) {
      FileService().closeVideo(h);
    }
    _currentFrame?.dispose();
    _currentFrame = null;
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
