import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../features/admin/admin_panel_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/terms_screen.dart';
import '../../features/auth/verify_code_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/chats_list_screen.dart';
import '../../features/events/create_event_screen.dart';
import '../../features/events/event_detail_screen.dart';
import '../../features/events/event_filters_screen.dart';
import '../../features/events/events_list_screen.dart';
import '../../features/events/incoming_applications_screen.dart';
import '../../features/feed/create_media_screen.dart';
import '../../features/feed/feed_screen.dart';
import '../../features/feed/story_viewer_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../data/models/story.dart';
import '../../features/profile/favorites_screen.dart';
import '../../features/profile/followers_list_screen.dart';
import '../../features/profile/host_profile_screen.dart';
import '../../features/profile/my_events_screen.dart';
import '../../features/profile/my_orders_screen.dart';
import '../../features/profile/my_profile_screen.dart';
import '../../features/profile/rate_screen.dart';
import '../../features/places/place_detail_screen.dart';
import '../../features/places/rate_place_screen.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/requests/create_request_screen.dart';
import '../../features/requests/requests_screen.dart';
import '../providers/auth_providers.dart';
import '../widgets/main_shell.dart';
import 'auth_refresh_listenable.dart';
import 'notifications_nav.dart';
import 'smooth_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

// Routes that require a signed-in account. Everything else (map, events
// list, event detail, host profiles) is browsable as a guest per App Store
// guideline 5.1.1(v) - only account-specific actions/screens are gated.
bool _routeRequiresAuth(String location) {
  if (isNotificationsLocation(location)) return true;
  const authOnlyPrefixes = [
    '/requests/create',
    '/requests',
    '/chat/',
    '/chats',
    '/home/chats',
    '/profile/edit',
    '/settings',
    '/rate/',
    '/rate-place/',
    '/my-orders',
    '/my-events',
    '/incoming-applications',
    '/favorites',
    '/admin',
    '/home/profile',
    '/events/create',
    '/create',
  ];
  if (authOnlyPrefixes.any(location.startsWith)) return true;
  if (location.startsWith('/events/') && location.endsWith('/edit')) return true;
  return false;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = AuthRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/welcome',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final signedIn = refreshListenable.isSignedIn;
      final location = state.matchedLocation;
      final onAuthFlow = location.startsWith('/welcome') ||
          location.startsWith('/login') ||
          location.startsWith('/register') ||
          location.startsWith('/verify');
      if (!signedIn && !onAuthFlow && _routeRequiresAuth(location)) {
        return '/welcome';
      }
      if (signedIn && onAuthFlow) {
        final user = ref.read(authStateProvider);
        if (user == null) return null;
        return postSignInRoute(user);
      }
      // Server-side (AdminGuard) is the real enforcement - this just keeps a
      // non-admin from ever seeing the screen render before their first API
      // call 403s.
      if (location.startsWith('/admin') &&
          ref.read(authStateProvider)?.role != UserRole.admin) {
        return '/home/profile';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => buildAuthPage(
          state: state,
          child: const WelcomeScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => buildAuthPage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => buildAuthPage(
          state: state,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/terms',
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const TermsScreen(),
        ),
      ),
      GoRoute(
        path: '/verify',
        pageBuilder: (context, state) => buildAuthPage(
          state: state,
          child: VerifyCodeScreen(
            phone: state.uri.queryParameters['phone'] ?? '',
            isRegister: state.uri.queryParameters['mode'] == 'register',
            name: state.uri.queryParameters['name'],
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [
              GoRoute(
                path: '/home/feed',
                pageBuilder: (context, state) => buildTabPage(
                  state: state,
                  child: const FeedScreen(),
                ),
                routes: notificationsChildRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/map',
                pageBuilder: (context, state) => buildTabPage(
                  state: state,
                  child: const MapScreen(),
                ),
                routes: notificationsChildRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/chats',
                pageBuilder: (context, state) => buildTabPage(
                  state: state,
                  child: const ChatsListScreen(),
                ),
                routes: notificationsChildRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/profile',
                pageBuilder: (context, state) => buildTabPage(
                  state: state,
                  child: const MyProfileScreen(),
                ),
                routes: notificationsChildRoutes(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/home/events',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: EventsListScreen(
            initialTab: state.uri.queryParameters['tab'],
          ),
        ),
      ),
      GoRoute(
        path: '/create',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final mode = state.uri.queryParameters['mode'] == 'story'
              ? CreateMediaMode.story
              : CreateMediaMode.post;
          return buildSmoothPage(
            state: state,
            child: CreateMediaScreen(
              initialMode: mode,
              prefillPlaceId: state.uri.queryParameters['placeId'],
              prefillPlaceName: state.uri.queryParameters['placeName'],
              prefillPlaceAddress: state.uri.queryParameters['placeAddress'],
              prefillStoryText: state.uri.queryParameters['text'],
              prefillImageUrl: state.uri.queryParameters['imageUrl'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/stories',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          List<StoryGroup> groups = const [];
          var initialGroup = 0;
          if (extra is StoryViewerArgs) {
            groups = extra.groups;
            initialGroup = extra.initialGroup;
          } else if (extra is Map) {
            groups = (extra['groups'] as List<StoryGroup>?) ?? const [];
            initialGroup = extra['initialGroup'] as int? ?? 0;
          }
          return buildSmoothPage(
            state: state,
            child: StoryViewerScreen(
              groups: groups,
              initialGroup: initialGroup,
            ),
          );
        },
      ),
      GoRoute(
        path: '/requests',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const RequestsScreen(),
        ),
      ),
      GoRoute(
        path: '/events/create',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const CreateEventScreen(),
        ),
      ),
      GoRoute(
        path: '/today',
        redirect: (context, state) => '/home/events?tab=today',
      ),
      GoRoute(
        path: '/afisha',
        redirect: (context, state) => '/home/events?tab=today',
      ),
      // Keep legacy deep links that opened the old home map tab.
      GoRoute(
        path: '/home',
        redirect: (context, state) => '/home/feed',
      ),
      GoRoute(
        path: '/events/:id/edit',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: CreateEventScreen(eventId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/events/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: EventDetailScreen(eventId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/filters',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const EventFiltersScreen(),
        ),
      ),
      GoRoute(
        path: '/requests/create',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const CreateRequestScreen(),
        ),
      ),
      GoRoute(
        path: '/chats',
        redirect: (context, state) => '/home/chats',
      ),
      GoRoute(
        path: '/chat/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: ChatScreen(chatId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/notifications',
        redirect: (context, state) => '/home/feed/notifications',
      ),
      GoRoute(
        path: '/host/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: HostProfileScreen(userId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/users/:id/followers',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: FollowersListScreen(userId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: EditProfileScreen(
            onboarding: state.uri.queryParameters['onboarding'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/rate/:eventId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: RateScreen(
            eventId: state.pathParameters['eventId']!,
            targetUserId: state.uri.queryParameters['targetId']!,
            targetRole: state.uri.queryParameters['role'] == 'guest'
                ? ReviewTargetRole.guest
                : ReviewTargetRole.host,
          ),
        ),
      ),
      GoRoute(
        path: '/places/:placeId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: PlaceDetailScreen(placeId: state.pathParameters['placeId']!),
        ),
      ),
      GoRoute(
        path: '/rate-place/:eventId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: RatePlaceScreen(
            eventId: state.pathParameters['eventId']!,
            placeId: state.uri.queryParameters['placeId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/my-orders',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const MyOrdersScreen(),
        ),
      ),
      GoRoute(
        path: '/incoming-applications',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const IncomingApplicationsScreen(),
        ),
      ),
      GoRoute(
        path: '/my-events',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const MyEventsScreen(),
        ),
      ),
      GoRoute(
        path: '/favorites',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const FavoritesScreen(),
        ),
      ),
      GoRoute(
        path: '/admin',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => buildSmoothPage(
          state: state,
          child: const AdminPanelScreen(),
        ),
      ),
    ],
  );
});
