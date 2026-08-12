import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/notifications_screen.dart';
import 'smooth_page.dart';

/// Opens notifications on the current shell tab so the floating bottom stays visible.
void pushNotifications(BuildContext context) {
  final path = GoRouterState.of(context).uri.path;
  if (path.endsWith('/notifications')) return;
  final match = RegExp(r'^(/home/(feed|map|chats|profile))').firstMatch(path);
  final base = match?.group(1) ?? '/home/feed';
  context.push('$base/notifications');
}

bool isNotificationsLocation(String path) => path.contains('/notifications');

List<RouteBase> notificationsChildRoutes() => [
      GoRoute(
        path: 'notifications',
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const NotificationsScreen(),
        ),
      ),
    ];
