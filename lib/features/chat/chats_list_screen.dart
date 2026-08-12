import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/main_shell.dart';
import '../../data/models/chat.dart';
import '../../data/models/user.dart';
import 'chats_providers.dart';

class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key});

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsProvider);
    final myId = ref.watch(authStateProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Чаты')),
      body: chatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState.fromError(
          e,
          onRetry: () => ref.invalidate(chatsProvider),
        ),
        data: (chats) {
          if (chats.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'Пока нет чатов',
              subtitle:
                  'Напишите человеку из профиля или откройте общий чат события после принятия заявки.',
            );
          }

          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? chats
              : chats.where((c) {
                  final title = c.titleFor(myId).toLowerCase();
                  final last = c.lastMessage?.text.toLowerCase() ?? '';
                  final names =
                      c.participants.map((p) => p.name.toLowerCase()).join(' ');
                  return title.contains(q) || last.contains(q) || names.contains(q);
                }).toList();

          final sorted = [...filtered]..sort((a, b) {
              final aAt = a.lastMessage?.createdAt ?? a.event?.startAt;
              final bAt = b.lastMessage?.createdAt ?? b.event?.startAt;
              if (aAt == null && bAt == null) return 0;
              if (aAt == null) return 1;
              if (bAt == null) return -1;
              return bAt.compareTo(aAt);
            });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Поиск по чатам',
                    prefixIcon: const Icon(Icons.search, size: 22),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              Expanded(
                child: sorted.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'Ничего не найдено',
                        subtitle: 'Попробуйте другое имя или название события.',
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.refresh(chatsProvider.future),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8 + kFloatingNavClearance),
                          itemCount: sorted.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
                          itemBuilder: (context, i) =>
                              _ChatTile(chat: sorted[i], myUserId: myId),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, this.myUserId});

  final Chat chat;
  final String? myUserId;

  AppUser? get _dmOther {
    if (!chat.isDirect) return null;
    for (final p in chat.participants) {
      if (p.id != myUserId) return p;
    }
    return chat.participants.isEmpty ? null : chat.participants.first;
  }

  @override
  Widget build(BuildContext context) {
    final title = chat.titleFor(myUserId);
    final last = chat.lastMessage;
    final unread = chat.unreadCount > 0;
    final other = _dmOther;
    final subtitle = last != null
        ? (chat.isDirect
            ? last.previewText
            : '${last.sender.name}: ${last.previewText}')
        : (chat.isDirect ? 'Начните переписку' : '${chat.participants.length} участников');
    final time = last?.createdAt;
    final avatarUrl = chat.event?.coverPhoto ??
        other?.avatarUrl ??
        (chat.participants.isEmpty ? null : chat.participants.first.avatarUrl);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: UserAvatar(
        url: avatarUrl,
        size: 48,
        name: title,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          color: unread ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (time != null)
            Text(
              formatTime(time),
              style: TextStyle(
                fontSize: 12,
                color: unread ? AppColors.primary : AppColors.textTertiary,
                fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          if (unread) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () => context.push('/chat/${chat.id}'),
    );
  }
}
