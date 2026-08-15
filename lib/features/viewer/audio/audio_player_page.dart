import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';

/// 音频播放器（APP 内部解码 + 内部输出，全链路 C++ 实现）
///
/// 播放流程：
/// 1. media 库（FFmpeg）完整解码为 S16 交错 PCM（base64 传输）。
/// 2. 平台层音频输出（Linux ALSA / Android AAudio / iOS AudioQueue / Windows WASAPI）。
/// 3. Timer 周期性将 PCM 分块送入音频输出设备。
class AudioPlayerPage extends StatefulWidget {
  final String path;
  const AudioPlayerPage({super.key, required this.path});

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';

  // 音频信息
  int _sampleRate = 0;
  int _channels = 0;
  int _bits = 0;

  // PCM 数据与播放状态
  Uint8List? _pcm;
  Pointer<Void>? _output;
  Timer? _timer;
  int _position = 0; // 已播放字节游标
  bool _playing = false;
  bool _disposed = false;

  double get _durationSeconds {
    if (_pcm == null || _sampleRate <= 0 || _channels <= 0) return 0;
    return _pcm!.length / (_sampleRate * _channels * 2);
  }

  double get _currentSeconds {
    if (_sampleRate <= 0 || _channels <= 0) return 0;
    return _position / (_sampleRate * _channels * 2);
  }

  @override
  void initState() {
    super.initState();
    _decodeAndInit();
  }

  Future<void> _decodeAndInit() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final fs = FileService();
      final result = fs.decodeAudio(widget.path);
      if (result == null) {
        setState(() {
          _loading = false;
          _error = true;
          _errorMsg = '无法解码音频文件';
        });
        return;
      }
      final b64 = result['base64'] as String?;
      if (b64 == null || b64.isEmpty) {
        setState(() {
          _loading = false;
          _error = true;
          _errorMsg = '音频数据为空';
        });
        return;
      }
      final pcm = base64Decode(b64);
      _sampleRate = (result['sample_rate'] ?? 0) as int;
      _channels = (result['channels'] ?? 0) as int;
      _bits = (result['bits'] ?? 16) as int;
      if (_sampleRate <= 0 || _channels <= 0 || pcm.isEmpty) {
        setState(() {
          _loading = false;
          _error = true;
          _errorMsg = '音频参数无效';
        });
        return;
      }
      // 打开平台层音频输出
      final out = fs.audioOutputOpen(_sampleRate, _channels, _bits);
      if (out == null) {
        setState(() {
          _loading = false;
          _error = true;
          _errorMsg = '无法打开音频输出设备';
        });
        return;
      }
      _pcm = pcm;
      _output = out;
      _position = 0;
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = true;
        _errorMsg = '解码错误: $e';
      });
    }
  }

  void _play() {
    if (_playing || _pcm == null || _output == null) return;
    if (_position >= _pcm!.length) {
      _position = 0; // 播完重播
    }
    setState(() => _playing = true);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _pump());
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (_playing) setState(() => _playing = false);
  }

  /// 每次推送约 100ms 的 PCM 到音频输出（阻塞式写入）。
  void _pump() {
    if (_disposed || _pcm == null || _output == null || !_playing) return;
    final pcm = _pcm!;
    final frameBytes = _sampleRate * _channels * 2 ~/ 10; // 100ms
    if (_position >= pcm.length) {
      _stopInternal();
      if (mounted) setState(() => _position = 0);
      return;
    }
    var chunk = frameBytes;
    if (_position + chunk > pcm.length) chunk = pcm.length - _position;
    final ptr = malloc<Uint8>(chunk);
    try {
      ptr.asTypedList(chunk).setAll(0, pcm.sublist(_position, _position + chunk));
      final written = FileService().audioOutputWrite(_output!, ptr, chunk);
      if (written > 0) {
        _position += written;
        if (mounted) setState(() {});
      } else if (written < 0) {
        _stopInternal();
      }
    } catch (_) {
      _stopInternal();
    } finally {
      malloc.free(ptr);
    }
  }

  void _stopInternal() {
    _timer?.cancel();
    _timer = null;
    if (_output != null) {
      FileService().audioOutputStop(_output!);
    }
    _playing = false;
  }

  void _seek(double seconds) {
    if (_pcm == null || _sampleRate <= 0 || _channels <= 0) return;
    final frameBytes = _sampleRate * _channels * 2;
    var pos = (seconds * frameBytes).round();
    if (pos < 0) pos = 0;
    if (pos > _pcm!.length) pos = _pcm!.length;
    setState(() {
      _position = pos;
      _playing = false;
    });
    _timer?.cancel();
    _timer = null;
    if (_output != null) FileService().audioOutputStop(_output!);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    final out = _output;
    _output = null;
    if (out != null) {
      FileService().audioOutputClose(out);
    }
    super.dispose();
  }

  String _formatTime(double seconds) {
    if (seconds.isNaN || seconds < 0) seconds = 0;
    final m = (seconds / 60).floor();
    final s = seconds.floor() % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatChannels(int ch) {
    switch (ch) {
      case 1:
        return '单声道';
      case 2:
        return '立体声';
      default:
        return '${ch}声道';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = FileService.getFileName(widget.path);
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : '';
    final duration = _durationSeconds;
    final current = _currentSeconds;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: _loading
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在解码音频...'),
                ],
              )
            : _error
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_errorMsg),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _decodeAndInit,
                        child: const Text('重试'),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 文件图标
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.audiotrack,
                                size: 48,
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ext,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 文件名
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        // 音频信息卡片
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _infoRow('采样率', '$_sampleRate Hz'),
                                const Divider(),
                                _infoRow('声道', _formatChannels(_channels)),
                                const Divider(),
                                _infoRow('位深度', '$_bits bit'),
                                const Divider(),
                                _infoRow(
                                  '时长',
                                  duration > 0
                                      ? _formatTime(duration)
                                      : '--:--',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 进度条
                        Row(
                          children: [
                            Text(
                              _formatTime(current),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            Expanded(
                              child: Slider(
                                value: duration > 0
                                    ? (current / duration).clamp(0.0, 1.0)
                                    : 0,
                                onChanged: (v) {
                                  if (duration > 0) _seek(v * duration);
                                },
                              ),
                            ),
                            Text(
                              duration > 0
                                  ? _formatTime(duration)
                                  : '--:--',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        // 播放控制
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10),
                              iconSize: 32,
                              onPressed: duration > 0
                                  ? () => _seek(current - 10)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                _playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed:
                                  _playing ? _pause : _play,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.forward_10),
                              iconSize: 32,
                              onPressed: duration > 0
                                  ? () => _seek(current + 10)
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '已通过 APP 内部 FFmpeg 解码 + 平台层音频输出播放',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
