import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/env.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/main_shell.dart';
import '../../core/widgets/pulse_wordmark.dart';
import '../../core/widgets/report_dialog.dart';
import '../../data/models/enums.dart';
import '../../data/models/feed_post.dart';
import '../../data/models/story.dart';
import 'feed_providers.dart';
import 'post_comments_sheet.dart';
import 'story_viewer_screen.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsFeedProvider);
    final storiesAsync = ref.watch(storiesFeedProvider);
    final signedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      appBar: AppBar(
        title: const PulseWordmark(fontSize: 20),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.plus, size: 28),
          onPressed: () {
            if (!signedIn) {
              context.push('/welcome');
              return;
            }
            context.push('/create');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.paperPlaneTilt, size: 28),
            tooltip: 'Чаты',
            onPressed: () {
              if (!signedIn) {
                context.push('/welcome');
                return;
              }
              context.go('/home/chats');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(storiesFeedProvider);
          await Future.wait([
            ref.read(postsFeedProvider.notifier).refresh(),
            ref.read(storiesFeedProvider.future),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: storiesAsync.when(
                loading: () => const SizedBox(height: 118),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Не удалось загрузить истории',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(storiesFeedProvider),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
                data: (groups) => _StoriesRow(
                  groups: groups,
                  onAdd: () {
                    if (!signedIn) {
                      context.push('/welcome');
                      return;
                    }
                    context.push('/create?mode=story');
                  },
                  onOpen: (index) => context.push(
                    '/stories',
                    extra: StoryViewerArgs(groups: groups, initialGroup: index),
                  ),
                ),
              ),
            ),
            postsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(postsFeedProvider),
                ),
              ),
              data: (posts) {
                if (posts.isEmpty) {
                  return const SliverFillRemaining(
                    child: EmptyState(
                      icon: PhosphorIconsRegular.images,
                      title: 'Лента пока пуста',
                      subtitle: 'Поделитесь вечером из Минска - фото и вайб',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: kFloatingNavClearance),
                  sliver: SliverList.separated(
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 18),
                    itemBuilder: (context, i) => _PostCard(post: posts[i]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({
    required this.groups,
    required this.onAdd,
    required this.onOpen,
  });

  final List<StoryGroup> groups;
  final VoidCallback onAdd;
  final void Function(int index) onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        itemCount: groups.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _StoryBubble(
              label: 'Ваша история',
              onTap: onAdd,
              isAdd: true,
            );
          }
          final g = groups[i - 1];
          return _StoryBubble(
            label: g.author.name,
            avatarUrl: g.author.avatarUrl,
            hasUnseen: g.hasUnseen,
            onTap: () => onOpen(i - 1),
          );
        },
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.label,
    required this.onTap,
    this.avatarUrl,
    this.hasUnseen = false,
    this.isAdd = false,
  });

  final String label;
  final String? avatarUrl;
  final bool hasUnseen;
  final bool isAdd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isAdd
                    ? null
                    : LinearGradient(
                        colors: hasUnseen
                            ? const [AppColors.primaryBright, AppColors.primary]
                            : [AppColors.border, AppColors.border],
                      ),
                border: isAdd ? Border.all(color: AppColors.border, width: 1.5) : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: AppColors.black, shape: BoxShape.circle),
                child: isAdd
                    ? Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(PhosphorIconsRegular.plus, color: AppColors.highlight),
                      )
                    : UserAvatar(url: avatarUrl, size: 56, name: label),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                height: 1.1,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = Env.resolveMediaUrl(post.imageUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/host/${post.author.id}'),
                child: UserAvatar(url: post.author.avatarUrl, size: 36, name: post.author.name),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/host/${post.author.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      if (post.place != null)
                        GestureDetector(
                          onTap: () => context.push('/places/${post.place!.id}'),
                          child: Text(
                            post.place!.name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(PhosphorIconsRegular.dotsThree, color: AppColors.textTertiary),
                onSelected: (value) {
                  if (value == 'report') {
                    showReportDialog(
                      context,
                      ref,
                      targetType: ComplaintTargetType.post,
                      targetId: post.id,
                    );
                  } else if (value == 'profile') {
                    context.push('/host/${post.author.id}');
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'profile', child: Text('Профиль')),
                  const PopupMenuItem(value: 'report', child: Text('Пожаловаться')),
                ],
              ),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: 1,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            memCacheWidth: 900,
            placeholder: (_, __) => Container(color: AppColors.surface),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.surface,
              child: const Icon(PhosphorIconsRegular.imageBroken, color: AppColors.textTertiary),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _requireAuthThen(context, ref, () async {
                  final ok =
                      await ref.read(postsFeedProvider.notifier).toggleLike(post);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Не удалось поставить лайк')),
                    );
                  }
                }),
                icon: Icon(
                  post.likedByMe ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                  color: post.likedByMe ? AppColors.primaryLight : AppColors.highlight,
                ),
              ),
              Text('${post.likesCount}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _requireAuthThen(context, ref, () {
                  showPostCommentsSheet(context, ref, post: post);
                }),
                icon: const Icon(PhosphorIconsRegular.chatCircle),
              ),
              if (post.commentsCount > 0)
                Text(
                  '${post.commentsCount}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              const Spacer(),
              IconButton(
                onPressed: () => _requireAuthThen(context, ref, () async {
                  final ok =
                      await ref.read(postsFeedProvider.notifier).toggleSave(post);
                  ref.invalidate(savedPostsProvider);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Не удалось сохранить пост')),
                    );
                  }
                }),
                icon: Icon(
                  post.savedByMe
                      ? PhosphorIconsFill.bookmarkSimple
                      : PhosphorIconsRegular.bookmarkSimple,
                  color: post.savedByMe ? AppColors.primaryLight : AppColors.highlight,
                ),
              ),
              IconButton(
                onPressed: () => _sharePost(post),
                icon: const Icon(PhosphorIconsRegular.shareFat),
                tooltip: 'Поделиться',
              ),
            ],
          ),
        ),
        if (post.commentsCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: GestureDetector(
              onTap: () => _requireAuthThen(context, ref, () {
                showPostCommentsSheet(context, ref, post: post);
              }),
              child: Text(
                post.commentsCount == 1
                    ? 'Смотреть комментарий'
                    : 'Смотреть все комментарии (${post.commentsCount})',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ),
        if (post.caption != null && post.caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${post.author.name} ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: post.caption),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            formatDayLabel(post.createdAt),
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  void _requireAuthThen(
    BuildContext context,
    WidgetRef ref,
    VoidCallback action,
  ) {
    if (!ref.read(isSignedInProvider)) {
      context.push('/welcome');
      return;
    }
    action();
  }

  Future<void> _sharePost(FeedPost post) async {
    final link = 'https://pulse.by/posts/${post.id}';
    final caption = (post.caption ?? '').trim();
    final text = caption.isEmpty
        ? 'Пост ${post.author.name} в Пульс\n$link'
        : '${post.author.name}: $caption\n$link';
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
