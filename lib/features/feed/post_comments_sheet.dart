import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/pulse_sheet.dart';
import '../../data/models/feed_post.dart';
import 'feed_providers.dart';

Future<void> showPostCommentsSheet(
  BuildContext context,
  WidgetRef ref, {
  required FeedPost post,
}) {
  return showPulseSheet<void>(
    context: context,
    heightFactor: 0.72,
    builder: (ctx) => _PostCommentsSheet(post: post),
  );
}

class _PostCommentsSheet extends ConsumerStatefulWidget {
  const _PostCommentsSheet({required this.post});

  final FeedPost post;

  @override
  ConsumerState<_PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends ConsumerState<_PostCommentsSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<PostComment>? _comments;
  Object? _error;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await ref.read(socialRepositoryProvider).listComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final signedIn = ref.read(isSignedInProvider);
    if (!signedIn) {
      Navigator.pop(context);
      context.push('/welcome');
      return;
    }
    setState(() => _sending = true);
    try {
      final res = await ref
          .read(socialRepositoryProvider)
          .addComment(widget.post.id, text);
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _comments = [...?_comments, res.comment];
        _sending = false;
      });
      ref.read(postsFeedProvider.notifier).setCommentsCount(
            widget.post.id,
            res.commentsCount,
          );
      ref.invalidate(savedPostsProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить комментарий')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulseSheetScaffold(
      title: 'Комментарии',
      trailing: const PulseSheetCloseButton(),
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Написать комментарий…',
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.highlight,
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    final comments = _comments ?? const <PostComment>[];
    if (comments.isEmpty) {
      return const Center(
        child: Text(
          'Пока нет комментариев',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      itemCount: comments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final c = comments[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                context.push('/host/${c.author.id}');
              },
              child: UserAvatar(
                url: c.author.avatarUrl,
                size: 36,
                name: c.author.name,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${c.author.name} ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: c.text),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDayLabel(c.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
