import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/report_dialog.dart';
import '../../core/widgets/social_links_row.dart';
import '../../data/models/enums.dart';
import '../../data/models/user.dart';
import '../chat/chats_providers.dart';
import '../events/events_providers.dart';
import '../monetization/monetization_actions.dart';

final _userByIdProvider = FutureProvider.family<AppUser, String>((ref, id) {
  return ref.watch(userRepositoryProvider).byId(id);
});

class HostProfileScreen extends ConsumerStatefulWidget {
  const HostProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends ConsumerState<HostProfileScreen> {
  bool? _followingOverride;
  bool _followBusy = false;
  bool? _blockedOverride;
  bool _blockBusy = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(_userByIdProvider(widget.userId));
    final me = ref.watch(authStateProvider);
    final isSelf = me?.id == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          if (!isSelf)
            userAsync.maybeWhen(
              data: (user) {
                final blocked = _blockedOverride ?? user.isBlockedByMe;
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  enabled: !_blockBusy,
                  onSelected: (value) {
                    if (value == 'report') {
                      showReportDialog(
                        context,
                        ref,
                        targetType: ComplaintTargetType.user,
                        targetId: widget.userId,
                      );
                    } else if (value == 'block') {
                      _toggleBlock(user, blocked);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'report', child: Text('Пожаловаться')),
                    PopupMenuItem(
                      value: 'block',
                      child: Text(blocked ? 'Разблокировать' : 'Заблокировать'),
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(_userByIdProvider(widget.userId)),
        ),
        data: (user) {
          final bio = user.bio?.trim();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  UserAvatar(url: user.avatarUrl, size: 72, name: user.name),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                formatUserName(user.name, user.age),
                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (user.hasActiveOrganizerPro) ...[
                              const SizedBox(width: 8),
                              const OrganizerProBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.city.isEmpty ? 'Минск' : user.city,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _Stat(
                    value: '${user.followersCount}',
                    label: followersLabel(user.followersCount),
                    onTap: () => context.push('/users/${user.id}/followers'),
                  ),
                  _Stat(
                    value: '${user.eventsCount}',
                    label: 'Событий',
                  ),
                ],
              ),
              if (bio != null && bio.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('О себе', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  bio,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              if (user.socialLinks.isNotEmpty) ...[
                const SizedBox(height: 20),
                SocialLinksRow(links: user.socialLinks),
              ],
              if (user.photos.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Фото', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: user.photos.length,
                    separatorBuilder: (c, i) => const SizedBox(width: 8),
                    itemBuilder: (c, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: Env.resolveMediaUrl(user.photos[i]),
                        width: 90,
                        height: 90,
                        memCacheWidth: 180,
                        memCacheHeight: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 100),
            ],
          );
        },
      ),
      bottomNavigationBar: userAsync.maybeWhen(
        data: (user) {
          if (isSelf) return null;
          final following = _followingOverride ?? user.isFollowing;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _followBusy ? null : () => _toggleFollow(user, following),
                      style: following
                          ? ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.textPrimary,
                            )
                          : null,
                      child: Text(
                        _followBusy
                            ? '…'
                            : (following ? 'Вы подписаны' : 'Подписаться'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () => _openHostChat(user),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }

  Future<void> _toggleFollow(AppUser user, bool currentlyFollowing) async {
    setState(() => _followBusy = true);
    try {
      if (currentlyFollowing) {
        await ref.read(userRepositoryProvider).unfollow(user.id);
        if (mounted) setState(() => _followingOverride = false);
      } else {
        await ref.read(userRepositoryProvider).follow(user.id);
        if (mounted) setState(() => _followingOverride = true);
      }
      ref.invalidate(_userByIdProvider(widget.userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось обновить подписку'))),
        );
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _toggleBlock(AppUser user, bool currentlyBlocked) async {
    setState(() => _blockBusy = true);
    try {
      if (currentlyBlocked) {
        await ref.read(userRepositoryProvider).unblock(user.id);
        if (mounted) setState(() => _blockedOverride = false);
      } else {
        await ref.read(userRepositoryProvider).block(user.id);
        if (mounted) setState(() => _blockedOverride = true);
      }
      ref.invalidate(eventsProvider);
      ref.invalidate(_userByIdProvider(widget.userId));
      if (mounted && !currentlyBlocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь заблокирован')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось обновить блокировку'))),
        );
      }
    } finally {
      if (mounted) setState(() => _blockBusy = false);
    }
  }

  Future<void> _openHostChat(AppUser user) async {
    try {
      final chat = await ref.read(chatRepositoryProvider).createDm(user.id);
      if (!mounted) return;
      ref.invalidate(chatsProvider);
      // ignore: use_build_context_synchronously
      context.push('/chat/${chat.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось открыть чат'))),
      );
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
      ],
    );
    return Expanded(
      child: onTap == null
          ? column
          : InkWell(
              onTap: onTap,
              child: column,
            ),
    );
  }
}

