import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/models/chat.dart';

final chatsProvider = FutureProvider<List<Chat>>((ref) {
  // Re-fetch when auth user changes (sign-in / account switch).
  ref.watch(authStateProvider);
  return ref.watch(chatRepositoryProvider).list();
});

final unreadChatsCountProvider = Provider<int>((ref) {
  return ref.watch(chatsProvider).maybeWhen(
        data: (chats) => chats.fold<int>(0, (sum, c) => sum + c.unreadCount),
        orElse: () => 0,
      );
});
