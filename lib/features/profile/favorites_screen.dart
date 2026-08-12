import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/config/env.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/event_list_tile.dart';
import '../../data/models/feed_post.dart';
import '../events/events_providers.dart';
import '../feed/feed_providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Избранное'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'События'),
              Tab(text: 'Посты'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FavoriteEventsTab(),
            _SavedPostsTab(),
          ],
        ),
      ),
    );
  }
}

class _FavoriteEventsTab extends ConsumerWidget {
  const _FavoriteEventsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(myFavoritesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(myFavoritesProvider.future),
      child: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(myFavoritesProvider),
        ),
        data: (events) {
          if (events.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.favorite_border,
                  title: 'Пока пусто',
                  subtitle:
                      'Добавляйте события в избранное, нажимая на сердечко',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: events.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final event = events[i];
              return EventListTile(
                event: event,
                onTap: () => context.push('/events/${event.id}'),
                onFavoriteChanged: () => ref.invalidate(myFavoritesProvider),
              );
            },
          );
        },
      ),
    );
  }
}

class _SavedPostsTab extends ConsumerWidget {
  const _SavedPostsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedPostsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(savedPostsProvider.future),
      child: savedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(savedPostsProvider),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: PhosphorIconsRegular.bookmarkSimple,
                  title: 'Нет сохранённых',
                  subtitle: 'Сохраняйте посты закладкой в ленте',
                ),
              ],
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: posts.length,
            itemBuilder: (context, i) => _SavedPostTile(post: posts[i]),
          );
        },
      ),
    );
  }
}

class _SavedPostTile extends ConsumerWidget {
  const _SavedPostTile({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = Env.resolveMediaUrl(post.imageUrl);
    return GestureDetector(
      onTap: () => context.push('/host/${post.author.id}'),
      onLongPress: () async {
        try {
          await ref.read(socialRepositoryProvider).unsave(post.id);
          ref.read(postsFeedProvider.notifier).setSaved(post.id, false);
          ref.invalidate(savedPostsProvider);
        } catch (_) {}
      },
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        placeholder: (_, __) => Container(color: AppColors.surface),
        errorWidget: (_, __, ___) => Container(
          color: AppColors.surface,
          child: const Icon(
            PhosphorIconsRegular.imageBroken,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
