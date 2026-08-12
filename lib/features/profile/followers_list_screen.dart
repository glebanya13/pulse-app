import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../data/models/user.dart';

final _followersProvider = FutureProvider.family<List<AppUser>, String>((ref, userId) {
  return ref.watch(userRepositoryProvider).listFollowers(userId);
});

/// People who follow [userId]. Tap a row to open their profile.
class FollowersListScreen extends ConsumerWidget {
  const FollowersListScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_followersProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Подписчики')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState.fromError(
          e,
          onRetry: () => ref.invalidate(_followersProvider(userId)),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'Пока нет подписчиков',
              subtitle: 'Когда кто-то подпишется, они появятся здесь.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_followersProvider(userId).future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
              itemBuilder: (context, i) {
                final user = users[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: UserAvatar(url: user.avatarUrl, size: 48, name: user.name),
                  title: Text(
                    formatUserName(user.name, user.age),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: user.city.isEmpty
                      ? null
                      : Text(
                          user.city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                  onTap: () => context.push('/host/${user.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
