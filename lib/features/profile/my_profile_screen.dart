import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/config/env.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/main_shell.dart';
import '../../core/widgets/pulse_sheet.dart';
import '../../core/widgets/social_links_row.dart';
import '../../data/api/api_client.dart';
import '../../data/api/firebase_social_auth.dart';
import '../../data/api/push_notifications.dart';
import '../../data/models/feed_post.dart';
import '../feed/feed_providers.dart';
import '../monetization/monetization_actions.dart';

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  Future<void> _signOut(WidgetRef ref) async {
    await PushNotifications.clearBackendToken(ApiClient.instance);
    await ref.read(authRepositoryProvider).logout();
    try {
      await FirebaseSocialAuth().signOutLocal();
    } catch (_) {}
    ref.read(authStateProvider.notifier).signOut();
  }

  Future<void> _becomeOrganizer(BuildContext context, WidgetRef ref) async {
    final ok = await showPulseConfirm(
      context: context,
      title: 'Стать организатором?',
      message:
          'Вы сможете публиковать события в афише Пульса: клубы, концерты, '
          'квизы и вечеринки. Зрители увидят их на карте и во вкладке «Сегодня».',
      icon: PhosphorIconsRegular.microphoneStage,
      cancelLabel: 'Позже',
      confirmLabel: 'Продолжить',
    );
    if (!ok || !context.mounted) return;
    try {
      final updated = await ref.read(userRepositoryProvider).becomeOrganizer();
      ref.read(authStateProvider.notifier).updateProfile(updated);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Готово - можно публиковать события')),
      );
      context.push('/events/create');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось: $e')),
      );
    }
  }

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    await showPulseSheet<void>(
      context: context,
      heightFactor: 0.55,
      builder: (ctx) => PulseSheetScaffold(
        title: 'Ещё',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
          children: [
            if (user.canHostEvents) ...[
              ListTile(
                leading: const Icon(PhosphorIconsRegular.calendarPlus),
                title: const Text('Создать событие'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/events/create');
                },
              ),
              ListTile(
                leading: const Icon(PhosphorIconsRegular.calendarBlank),
                title: const Text('Мои события'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/my-events');
                },
              ),
            ] else
              ListTile(
                leading: const Icon(PhosphorIconsRegular.microphoneStage),
                title: const Text('Стать организатором'),
                onTap: () {
                  Navigator.pop(ctx);
                  _becomeOrganizer(context, ref);
                },
              ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.ticket),
              title: const Text('Я иду'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/my-orders');
              },
            ),
            if (user.isAdmin)
              ListTile(
                leading: const Icon(PhosphorIconsRegular.shieldCheck),
                title: const Text('Админ панель'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/admin');
                },
              ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.signOut, color: AppColors.danger),
              title: const Text('Выйти', style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _signOut(ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final postsAsync = ref.watch(userPostsProvider(user.id));
    final storiesAsync = ref.watch(storiesFeedProvider);
    final hasActiveStory = storiesAsync.maybeWhen(
      data: (groups) => groups.any((g) => g.author.id == user.id && g.items.isNotEmpty),
      orElse: () => false,
    );
    final bio = user.bio?.trim();
    final postsCount = postsAsync.maybeWhen(data: (p) => p.length, orElse: () => 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(user.name.isEmpty ? 'Профиль' : user.name),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.bookmarkSimple),
            onPressed: () => context.push('/favorites'),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.gearSix),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.list),
            onPressed: () => _openMenu(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userPostsProvider(user.id));
          ref.invalidate(storiesFeedProvider);
          await ref.read(userPostsProvider(user.id).future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: hasActiveStory
                                ? const LinearGradient(
                                    colors: [AppColors.primaryBright, AppColors.primary],
                                  )
                                : null,
                            border: hasActiveStory
                                ? null
                                : Border.all(color: AppColors.border, width: 1),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.black,
                              shape: BoxShape.circle,
                            ),
                            child: UserAvatar(
                              url: user.avatarUrl,
                              size: 78,
                              name: user.name,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _IgStat(value: '$postsCount', label: 'посты'),
                              ),
                              Expanded(
                                child: _IgStat(
                                  value: '${user.followersCount}',
                                  label: 'подписчики',
                                  onTap: () =>
                                      context.push('/users/${user.id}/followers'),
                                ),
                              ),
                              Expanded(
                                child: _IgStat(
                                  value: '${user.followingCount}',
                                  label: 'подписки',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        if (user.hasActiveOrganizerPro) ...[
                          const SizedBox(width: 8),
                          const OrganizerProBadge(compact: true),
                        ],
                      ],
                    ),
                    if (bio != null && bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        bio,
                        style: const TextStyle(
                          height: 1.4,
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (user.socialLinks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SocialLinksRow(links: user.socialLinks),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => context.push('/profile/edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: AppColors.surfaceAlt,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Редактировать профиль',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    if (user.canHostEvents) ...[
                      const SizedBox(height: 20),
                      const OrganizerToolsBlock(),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Divider(height: 1, color: AppColors.border),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Text(
                  'Публикации',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.3,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
            postsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$e', textAlign: TextAlign.center),
                ),
              ),
              data: (posts) {
                if (posts.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 80),
                      child: Column(
                        children: [
                          Icon(
                            PhosphorIconsRegular.images,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Пока нет постов',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Опубликуйте фото из ленты на вкладке «Дом»',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: kFloatingNavClearance),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 1.5,
                      mainAxisSpacing: 1.5,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _PostThumb(post: posts[i]),
                      childCount: posts.length,
                    ),
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

class _IgStat extends StatelessWidget {
  const _IgStat({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          textAlign: TextAlign.center,
        ),
      ],
    );
    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}

class _PostThumb extends StatelessWidget {
  const _PostThumb({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final url = Env.resolveMediaUrl(post.imageUrl);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      placeholder: (_, __) => Container(color: AppColors.surface),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.surface,
        child: const Icon(PhosphorIconsRegular.imageBroken, size: 20),
      ),
    );
  }
}
