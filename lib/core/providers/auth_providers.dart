import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_data.dart';
import '../../data/models/user.dart';
import '../config/env.dart';

/// Null when signed out. Seeded to null so the app opens on the welcome
/// screen; sign in sets it to the authenticated user.
class AuthState extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  void signIn(AppUser user) => state = user;

  void signOut() => state = null;

  void updateProfile(AppUser user) => state = user;
}

final authStateProvider = NotifierProvider<AuthState, AppUser?>(AuthState.new);

/// Where to land right after a successful sign-in. Shared by the router's
/// passive redirect and the auth screens' explicit post-signIn navigation
/// (needed because /welcome and /verify are usually reached via `push`,
/// which the redirect-on-state-change mechanism doesn't reliably unwind).
String postSignInRoute(AppUser user) {
  final needsProfile = user.name.trim().isEmpty || user.name == 'Новый пользователь';
  return needsProfile ? '/profile/edit?onboarding=1' : '/home/feed';
}

final isSignedInProvider = Provider<bool>((ref) => ref.watch(authStateProvider) != null);

/// Current user for signed-in screens (router already redirects guests away).
/// Falls back to [MockData.me] only in mock mode so design previews work
/// without a login step. Never invents a user against a real API session.
final currentUserProvider = Provider<AppUser>((ref) {
  final user = ref.watch(authStateProvider);
  if (user != null) return user;
  if (Env.useMockData) return MockData.me;
  throw StateError('currentUserProvider used while signed out');
});
