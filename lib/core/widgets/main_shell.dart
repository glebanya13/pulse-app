import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../providers/auth_providers.dart';
import '../router/notifications_nav.dart';
import '../../data/models/user.dart' hide Badge;
import '../../features/chat/chats_providers.dart';
import '../../features/notifications/notifications_providers.dart';
import 'avatar.dart';

/// Floating pill height used to clear map FABs / list bottoms.
const kFloatingNavClearance = 78.0;

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const double _iconSize = 26;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    // Only badge counts - not full lists (avoids rebuilding shell on every chat/notif item).
    final unreadNotifs = signedIn ? ref.watch(unreadNotificationsCountProvider) : 0;
    final unreadChats = signedIn ? ref.watch(unreadChatsCountProvider) : 0;
    final user = ref.watch(authStateProvider);
    final onNotifications = isNotificationsLocation(GoRouterState.of(context).uri.path);

    return Scaffold(
      extendBody: true,
      // No Opacity/Transform on the shell: that forces the Yandex map (PlatformView)
      // to recompose every frame and is the main source of tab stutter.
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xF2141416),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  _NavIcon(
                    selected: !onNotifications && navigationShell.currentIndex == 0,
                    icon: PhosphorIconsRegular.house,
                    activeIcon: PhosphorIconsFill.house,
                    onTap: () => _goBranch(context, 0, signedIn: true),
                  ),
                  _NavIcon(
                    selected: !onNotifications && navigationShell.currentIndex == 1,
                    icon: PhosphorIconsRegular.magnifyingGlass,
                    activeIcon: PhosphorIconsFill.magnifyingGlass,
                    onTap: () => _goBranch(context, 1, signedIn: true),
                  ),
                  _NavIcon(
                    selected: !onNotifications && navigationShell.currentIndex == 2,
                    icon: PhosphorIconsRegular.paperPlaneTilt,
                    activeIcon: PhosphorIconsFill.paperPlaneTilt,
                    unread: unreadChats,
                    onTap: () => _goBranch(context, 2, signedIn: signedIn, requiresAuth: true),
                  ),
                  _NavIcon(
                    selected: onNotifications,
                    icon: PhosphorIconsRegular.bell,
                    activeIcon: PhosphorIconsFill.bell,
                    unread: unreadNotifs,
                    onTap: () {
                      if (!signedIn) {
                        context.push('/welcome');
                        return;
                      }
                      pushNotifications(context);
                    },
                  ),
                  _ProfileNavSlot(
                    selected: !onNotifications && navigationShell.currentIndex == 3,
                    user: user,
                    onTap: () => _goBranch(context, 3, signedIn: signedIn, requiresAuth: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goBranch(
    BuildContext context,
    int index, {
    required bool signedIn,
    bool requiresAuth = false,
  }) {
    if (requiresAuth && !signedIn) {
      context.push('/welcome');
      return;
    }
    const destinations = [
      '/home/feed',
      '/home/map',
      '/home/chats',
      '/home/profile',
    ];
    if (isNotificationsLocation(GoRouterState.of(context).uri.path)) {
      context.go(destinations[index]);
      return;
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.selected,
    required this.icon,
    required this.activeIcon,
    required this.onTap,
    this.unread = 0,
  });

  final bool selected;
  final IconData icon;
  final IconData activeIcon;
  final VoidCallback onTap;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.highlight : const Color(0xFF8E8E93);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.primary,
            smallSize: 8,
            label: unread > 9
                ? const Text('9+', style: TextStyle(fontSize: 9, color: Colors.white))
                : (unread > 0
                    ? Text('$unread', style: const TextStyle(fontSize: 9, color: Colors.white))
                    : null),
            child: Icon(
              selected ? activeIcon : icon,
              color: color,
              size: MainShell._iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileNavSlot extends StatelessWidget {
  const _ProfileNavSlot({
    required this.selected,
    required this.user,
    required this.onTap,
  });

  final bool selected;
  final AppUser? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.primaryLight : Colors.transparent,
                width: 2,
              ),
            ),
            child: user == null
                ? const Icon(
                    PhosphorIconsRegular.userCircle,
                    color: Color(0xFF8E8E93),
                    size: 28,
                  )
                : UserAvatar(url: user!.avatarUrl, size: 28, name: user!.name),
          ),
        ),
      ),
    );
  }
}
