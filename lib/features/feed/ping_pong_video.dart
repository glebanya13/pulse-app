import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Drives a short clip forward then backward (Instagram-style boomerang).
class PingPongVideo extends StatefulWidget {
  const PingPongVideo.file({
    super.key,
    required File file,
    this.fit = BoxFit.cover,
  })  : _file = file,
        _url = null;

  const PingPongVideo.network({
    super.key,
    required String url,
    this.fit = BoxFit.cover,
  })  : _url = url,
        _file = null;

  final File? _file;
  final String? _url;
  final BoxFit fit;

  @override
  State<PingPongVideo> createState() => PingPongVideoState();
}

class PingPongVideoState extends State<PingPongVideo> {
  VideoPlayerController? _controller;
  Timer? _tick;
  bool _forward = true;
  static const _step = Duration(milliseconds: 33);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant PingPongVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sameFile = oldWidget._file?.path == widget._file?.path;
    final sameUrl = oldWidget._url == widget._url;
    if (!sameFile || !sameUrl) {
      _disposeController();
      _init();
    }
  }

  Future<void> _init() async {
    final file = widget._file;
    final url = widget._url;
    final VideoPlayerController c;
    if (file != null) {
      c = VideoPlayerController.file(file);
    } else if (url != null && url.isNotEmpty) {
      c = VideoPlayerController.networkUrl(Uri.parse(url));
    } else {
      return;
    }
    _controller = c;
    try {
      await c.initialize();
      if (!mounted || _controller != c) {
        await c.dispose();
        return;
      }
      await c.setVolume(0);
      await c.setLooping(false);
      await c.pause();
      await c.seekTo(Duration.zero);
      _forward = true;
      _startTicker();
      setState(() {});
    } catch (_) {
      await c.dispose();
      if (_controller == c) _controller = null;
    }
  }

  void _startTicker() {
    _tick?.cancel();
    _tick = Timer.periodic(_step, (_) => _onTick());
  }

  Future<void> _onTick() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur.inMilliseconds < 80) return;

    var pos = c.value.position;
    if (_forward) {
      pos += _step;
      if (pos >= dur) {
        pos = dur;
        _forward = false;
      }
    } else {
      pos -= _step;
      if (pos <= Duration.zero) {
        pos = Duration.zero;
        _forward = true;
      }
    }
    try {
      await c.seekTo(pos);
    } catch (_) {}
  }

  void pause() {
    _tick?.cancel();
    _tick = null;
  }

  void resume() {
    if (_tick == null && _controller?.value.isInitialized == true) {
      _startTicker();
    }
  }

  Future<void> _disposeController() async {
    _tick?.cancel();
    _tick = null;
    final c = _controller;
    _controller = null;
    await c?.dispose();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return FittedBox(
      fit: widget.fit,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}
