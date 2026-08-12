import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/config/env.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/report_dialog.dart';
import '../../data/models/enums.dart';
import '../../data/models/story.dart';
import 'feed_providers.dart';
import 'ping_pong_video.dart';

class StoryViewerArgs {
  const StoryViewerArgs({
    required this.groups,
    this.initialGroup = 0,
  });

  final List<StoryGroup> groups;
  final int initialGroup;
}

bool _isAnimatedImageUrl(String url) {
  final path = url.toLowerCase().split('?').first;
  return path.endsWith('.gif') || path.endsWith('.webp');
}

class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    this.initialGroup = 0,
  });

  final List<StoryGroup> groups;
  final int initialGroup;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _groupIndex;
  late int _itemIndex;
  late AnimationController _progress;
  Timer? _markViewed;
  final GlobalKey<PingPongVideoState> _videoKey = GlobalKey<PingPongVideoState>();

  StoryGroup get _group => widget.groups[_groupIndex];
  StoryItem get _item => _group.items[_itemIndex];

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroup.clamp(0, widget.groups.length - 1);
    _itemIndex = 0;
    _progress = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCurrent());
  }

  @override
  void dispose() {
    _markViewed?.cancel();
    _progress.dispose();
    super.dispose();
  }

  Duration _durationFor(StoryItem item, String imageUrl) {
    if (item.hasVideo) return const Duration(seconds: 8);
    if (_isAnimatedImageUrl(imageUrl)) return const Duration(seconds: 8);
    return const Duration(seconds: 5);
  }

  void _startCurrent() {
    final imageUrl = Env.resolveMediaUrl(_item.imageUrl);
    _progress.duration = _durationFor(_item, imageUrl);
    _progress
      ..stop()
      ..reset()
      ..forward();
    setState(() {});

    _markViewed?.cancel();
    _markViewed = Timer(const Duration(milliseconds: 400), () {
      ref.read(socialRepositoryProvider).viewStory(_item.id).then((_) {
        ref.invalidate(storiesFeedProvider);
      }).catchError((_) {});
    });
  }

  void _next() {
    if (_itemIndex < _group.items.length - 1) {
      setState(() => _itemIndex++);
      _startCurrent();
      return;
    }
    if (_groupIndex < widget.groups.length - 1) {
      setState(() {
        _groupIndex++;
        _itemIndex = 0;
      });
      _startCurrent();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _prev() {
    if (_itemIndex > 0) {
      setState(() => _itemIndex--);
      _startCurrent();
      return;
    }
    if (_groupIndex > 0) {
      setState(() {
        _groupIndex--;
        _itemIndex = widget.groups[_groupIndex].items.length - 1;
      });
      _startCurrent();
    } else {
      _startCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groups.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black, body: SizedBox.shrink());
    }
    final imageUrl = Env.resolveMediaUrl(_item.imageUrl);
    final videoRaw = _item.videoUrl?.trim();
    final videoUrl = (videoRaw == null || videoRaw.isEmpty)
        ? null
        : Env.resolveMediaUrl(videoRaw);
    final animated = _isAnimatedImageUrl(imageUrl);
    final showVideo = _item.hasVideo && videoUrl != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          final w = MediaQuery.sizeOf(context).width;
          if (d.localPosition.dx < w * 0.35) {
            _prev();
          } else {
            _next();
          }
        },
        onLongPressStart: (_) {
          _progress.stop();
          _videoKey.currentState?.pause();
        },
        onLongPressEnd: (_) {
          _progress.forward();
          _videoKey.currentState?.resume();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showVideo)
              PingPongVideo.network(key: _videoKey, url: videoUrl)
            else if (animated)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Colors.black,
                  child: Icon(
                    PhosphorIconsRegular.imageBroken,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const ColoredBox(color: Colors.black);
                },
              )
            else
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 1200,
                placeholder: (_, _) => const ColoredBox(color: Colors.black),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Colors.black,
                  child: Icon(
                    PhosphorIconsRegular.imageBroken,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Color(0x99000000), Color(0x00000000)],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < _group.items.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _progress,
                              builder: (_, _) {
                                double value;
                                if (i < _itemIndex) {
                                  value = 1;
                                } else if (i > _itemIndex) {
                                  value = 0;
                                } else {
                                  value = _progress.value;
                                }
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    minHeight: 2.5,
                                    backgroundColor: Colors.white24,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        UserAvatar(
                          url: _group.author.avatarUrl,
                          size: 36,
                          name: _group.author.name,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _group.author.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_item.place != null)
                                GestureDetector(
                                  onTap: () =>
                                      context.push('/places/${_item.place!.id}'),
                                  child: Text(
                                    _item.place!.name,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => showReportDialog(
                            context,
                            ref,
                            targetType: ComplaintTargetType.story,
                            targetId: _item.id,
                          ),
                          icon: const Icon(
                            PhosphorIconsRegular.dotsThree,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(PhosphorIconsRegular.x, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
