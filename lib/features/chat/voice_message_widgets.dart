import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/chat.dart';

/// Shared player so only one voice note plays at a time.
final _voicePlayer = AudioPlayer();
String? _playingMessageId;

class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  final ChatMessage message;
  final bool isMe;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  bool _playing = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _playing = _playingMessageId == widget.message.id;
    _stateSub = _voicePlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      final mine = _playingMessageId == widget.message.id;
      setState(() {
        _playing = mine && state == PlayerState.playing;
        if (state == PlayerState.completed && mine) {
          _progress = 0;
          _playingMessageId = null;
          _playing = false;
        }
      });
    });
    _posSub = _voicePlayer.onPositionChanged.listen((pos) {
      if (!mounted || _playingMessageId != widget.message.id) return;
      final total = widget.message.durationMs ?? 0;
      if (total <= 0) return;
      setState(() => _progress = (pos.inMilliseconds / total).clamp(0.0, 1.0));
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    final url = widget.message.audioUrl;
    if (url == null) return;
    final resolved = Env.resolveMediaUrl(url);

    if (_playing && _playingMessageId == widget.message.id) {
      await _voicePlayer.pause();
      return;
    }

    _playingMessageId = widget.message.id;
    await _voicePlayer.stop();
    await _voicePlayer.play(UrlSource(resolved));
    if (mounted) setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final onPrimary = widget.isMe;
    final fg = onPrimary ? AppColors.white : AppColors.textPrimary;
    final muted = onPrimary ? AppColors.white.withValues(alpha: 0.7) : AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggle,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Icon(
            _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: fg,
            size: 32,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _playing || _progress > 0 ? _progress : 0,
                  minHeight: 3,
                  backgroundColor: muted.withValues(alpha: 0.25),
                  color: fg,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.message.durationLabel,
                style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

typedef VoiceSendCallback = Future<void> Function(File file, int durationMs);

/// Mic button + recording bar for the chat composer.
class VoiceComposerControls extends StatefulWidget {
  const VoiceComposerControls({
    super.key,
    required this.enabled,
    required this.onSend,
    required this.onError,
    this.onRecordingChanged,
  });

  final bool enabled;
  final VoiceSendCallback onSend;
  final void Function(String message) onError;
  final ValueChanged<bool>? onRecordingChanged;

  @override
  State<VoiceComposerControls> createState() => VoiceComposerControlsState();
}

class VoiceComposerControlsState extends State<VoiceComposerControls> {
  final _recorder = AudioRecorder();
  Timer? _tick;
  bool _recording = false;
  bool _busy = false;
  int _elapsedMs = 0;
  String? _path;
  DateTime? _startedAt;

  bool get isRecording => _recording;

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  void _setRecording(bool value) {
    if (_recording == value) return;
    setState(() => _recording = value);
    widget.onRecordingChanged?.call(value);
  }

  Future<void> startOrToggle() async {
    if (_busy || !widget.enabled) return;
    if (_recording) {
      await _finishAndSend();
      return;
    }
    await _start();
  }

  Future<void> _start() async {
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        widget.onError('Нужен доступ к микрофону');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'pulse_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      if (!mounted) return;
      _path = path;
      _startedAt = DateTime.now();
      _elapsedMs = 0;
      _setRecording(true);
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || _startedAt == null) return;
        final ms = DateTime.now().difference(_startedAt!).inMilliseconds;
        setState(() => _elapsedMs = ms);
        if (ms >= 120000) {
          unawaited(_finishAndSend());
        }
      });
    } catch (_) {
      widget.onError('Не удалось начать запись');
    }
  }

  Future<void> cancel() async {
    _tick?.cancel();
    try {
      await _recorder.cancel();
    } catch (_) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    final path = _path;
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _elapsedMs = 0;
      _path = null;
      _startedAt = null;
      _busy = false;
    });
    _setRecording(false);
  }

  Future<void> _finishAndSend() async {
    if (!_recording || _busy) return;
    setState(() => _busy = true);
    _tick?.cancel();
    try {
      final path = await _recorder.stop() ?? _path;
      final durationMs = _elapsedMs;
      if (!mounted) return;
      setState(() {
        _path = null;
        _startedAt = null;
      });
      _setRecording(false);
      if (path == null || durationMs < 500) {
        widget.onError('Слишком короткое голосовое');
        return;
      }
      await widget.onSend(File(path), durationMs);
    } catch (_) {
      widget.onError('Не удалось отправить голосовое');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _timerLabel {
    final totalSec = (_elapsedMs / 1000).floor();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_recording) {
      return Row(
        children: [
          IconButton(
            onPressed: _busy ? null : cancel,
            icon: const Icon(Icons.close, color: AppColors.danger),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Запись $_timerLabel',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            onPressed: (_busy || !widget.enabled) ? null : _finishAndSend,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      );
    }

    return IconButton(
      onPressed: (!widget.enabled || _busy) ? null : startOrToggle,
      tooltip: 'Голосовое сообщение',
      icon: const Icon(Icons.mic_none_outlined),
      color: AppColors.primary,
    );
  }
}
