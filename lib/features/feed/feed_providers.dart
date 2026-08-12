import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../data/models/feed_post.dart';
import '../../data/models/story.dart';

class PostsFeedNotifier extends AsyncNotifier<List<FeedPost>> {
  @override
  Future<List<FeedPost>> build() {
    return ref.watch(socialRepositoryProvider).listPosts();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(socialRepositoryProvider).listPosts(),
    );
  }

  void _patch(String postId, FeedPost Function(FeedPost) fn) {
    final list = state.valueOrNull;
    if (list == null) return;
    state = AsyncData([
      for (final p in list) if (p.id == postId) fn(p) else p,
    ]);
  }

  Future<bool> toggleLike(FeedPost post) async {
    final prev = state.valueOrNull;
    if (prev == null) return false;
    final liked = !post.likedByMe;
    final optimisticCount =
        (post.likesCount + (liked ? 1 : -1)).clamp(0, 1 << 30);
    _patch(
      post.id,
      (p) => p.copyWith(likedByMe: liked, likesCount: optimisticCount),
    );
    try {
      final repo = ref.read(socialRepositoryProvider);
      final res = liked ? await repo.like(post.id) : await repo.unlike(post.id);
      _patch(
        post.id,
        (p) => p.copyWith(likedByMe: res.liked, likesCount: res.likesCount),
      );
      return true;
    } catch (_) {
      state = AsyncData(prev);
      return false;
    }
  }

  Future<bool> toggleSave(FeedPost post) async {
    final prev = state.valueOrNull;
    if (prev == null) return false;
    final saved = !post.savedByMe;
    _patch(post.id, (p) => p.copyWith(savedByMe: saved));
    try {
      final repo = ref.read(socialRepositoryProvider);
      final ok = saved ? await repo.save(post.id) : await repo.unsave(post.id);
      _patch(post.id, (p) => p.copyWith(savedByMe: ok));
      return true;
    } catch (_) {
      state = AsyncData(prev);
      return false;
    }
  }

  void setCommentsCount(String postId, int count) {
    _patch(postId, (p) => p.copyWith(commentsCount: count));
  }

  void setSaved(String postId, bool saved) {
    _patch(postId, (p) => p.copyWith(savedByMe: saved));
  }
}

final postsFeedProvider =
    AsyncNotifierProvider<PostsFeedNotifier, List<FeedPost>>(PostsFeedNotifier.new);

final userPostsProvider =
    FutureProvider.family<List<FeedPost>, String>((ref, authorId) {
  return ref.watch(socialRepositoryProvider).listPosts(authorId: authorId);
});

final savedPostsProvider = FutureProvider<List<FeedPost>>((ref) {
  return ref.watch(socialRepositoryProvider).listSavedPosts();
});

final storiesFeedProvider = FutureProvider<List<StoryGroup>>((ref) {
  return ref.watch(socialRepositoryProvider).storiesFeed();
});
