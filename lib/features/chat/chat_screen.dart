import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/report_dialog.dart';
import '../../data/api/chat_socket.dart';
import '../../data/models/chat.dart';
import '../../data/models/enums.dart';
import '../../data/models/user.dart';
import 'chat_attachment_widgets.dart';
import 'chats_providers.dart';
import 'voice_message_widgets.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _socket = ChatSocket();

  List<ChatMessage> _messages = [];
  Chat? _chat;
  Object? _error;
  Timer? _fallbackPoll;
  bool _loading = true;
  bool _sending = false;
  bool _syncing = false;
  bool _wsConnected = false;
  bool _recording = false;
  final _voiceKey = GlobalKey<VoiceComposerControlsState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_markReadAndRefreshBadge());
    _socket.onMessage = _onSocketMessage;
    _socket.onConnectionChanged = (connected) {
      if (!mounted) return;
      setState(() => _wsConnected = connected);
      _configureFallbackPolling();
      if (connected) {
        // Catch anything missed while reconnecting.
        _syncMessages();
      }
    };
    _loadInitial();
  }

  Future<void> _markReadAndRefreshBadge() async {
    try {
      await ref.read(chatRepositoryProvider).markRead(widget.chatId);
    } catch (_) {}
    if (mounted) ref.invalidate(chatsProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fallbackPoll?.cancel();
    _socket.leave(widget.chatId);
    unawaited(_socket.disconnect());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_socket.reconnectWithFreshToken());
      _syncMessages();
      _configureFallbackPolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _fallbackPoll?.cancel();
      _fallbackPoll = null;
      unawaited(_socket.disconnect());
    }
  }

  void _configureFallbackPolling() {
    _fallbackPoll?.cancel();
    _fallbackPoll = null;
    if (!mounted || _chat == null) return;

    // Fast poll only when the socket is down; slow safety net while connected.
    final interval = _wsConnected ? const Duration(seconds: 30) : const Duration(seconds: 4);
    _fallbackPoll = Timer.periodic(interval, (_) => _syncMessages());
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chat = await ref.read(chatRepositoryProvider).byId(widget.chatId);
      if (!mounted) return;
      setState(() {
        _chat = chat;
        _messages = chat.messages;
        _loading = false;
      });
      _scrollToEnd(jump: true);
      _socket.join(widget.chatId);
      await _socket.connect();
      _configureFallbackPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onSocketMessage(ChatMessage message) {
    if (!mounted) return;
    final nearBottom = !_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent - _scrollController.offset < 120;
    final isNew = !_messages.any((m) => m.id == message.id);
    if (!isNew) return;

    setState(() => _messages = [..._messages, message]);
    unawaited(_markReadAndRefreshBadge());
    if (nearBottom) _scrollToEnd();
  }

  Future<void> _syncMessages() async {
    if (_chat == null || _syncing) return;
    _syncing = true;
    try {
      final messages = await ref.read(chatRepositoryProvider).messages(widget.chatId);
      if (!mounted) return;
      final previousLastId = _messages.isEmpty ? null : _messages.last.id;
      final nearBottom = !_scrollController.hasClients ||
          _scrollController.position.maxScrollExtent - _scrollController.offset < 120;
      final hasNew = messages.isNotEmpty && messages.last.id != previousLastId;
      setState(() => _messages = messages);
      if (hasNew) {
        await _markReadAndRefreshBadge();
        if (nearBottom) _scrollToEnd();
      }
    } catch (_) {
      // Keep last known messages while offline.
    } finally {
      _syncing = false;
    }
  }

  void _scrollToEnd({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _recording) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      final me = ref.read(currentUserProvider);
      final message = await ref.read(chatRepositoryProvider).sendMessage(widget.chatId, me, text);
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages = [..._messages, message];
        }
      });
      _scrollToEnd();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось отправить'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendVoice(File file, int durationMs) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final me = ref.read(currentUserProvider);
      final message = await ref.read(chatRepositoryProvider).sendVoice(
            chatId: widget.chatId,
            sender: me,
            file: file,
            durationMs: durationMs,
          );
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages = [..._messages, message];
        }
      });
      _scrollToEnd();
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось отправить голосовое'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAttachment(File file, {String? filename}) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final me = ref.read(currentUserProvider);
      final message = await ref.read(chatRepositoryProvider).sendAttachment(
            chatId: widget.chatId,
            sender: me,
            file: file,
            filename: filename,
          );
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages = [..._messages, message];
        }
      });
      _scrollToEnd();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось отправить файл'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showAttachSheet() async {
    if (_sending || _recording) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Прикрепить',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                title: const Text('Камера'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1920,
                    imageQuality: 85,
                  );
                  if (picked == null) return;
                  await _sendAttachment(File(picked.path), filename: picked.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Фото из галереи'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1920,
                    imageQuality: 85,
                  );
                  if (picked == null) return;
                  await _sendAttachment(File(picked.path), filename: picked.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.collections_outlined, color: AppColors.primary),
                title: const Text('Несколько фото'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final picked = await ImagePicker().pickMultiImage(
                    maxWidth: 1920,
                    imageQuality: 85,
                    limit: 5,
                  );
                  for (final x in picked) {
                    await _sendAttachment(File(x.path), filename: x.name);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showParticipants(List<AppUser> participants) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Кто в чате',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (participants.isEmpty)
                const Text(
                  'Пока никого нет',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                ...participants.map(
                  (p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(url: p.avatarUrl, size: 40, name: p.name),
                    title: Text(formatUserName(p.name, p.age)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push('/host/${p.id}');
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider);

    if (_loading && _chat == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _chat == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Чат')),
        body: ErrorState.fromError(
          _error!,
          onRetry: _loadInitial,
        ),
      );
    }

    final displayChat = _chat!;
    final myId = me?.id;
    final isDirect = displayChat.isDirect ||
        (displayChat.event == null && displayChat.participants.length == 2);
    final dmOther = isDirect
        ? displayChat.participants.where((p) => p.id != myId).firstOrNull
        : null;
    final title = displayChat.event?.title ?? dmOther?.name ?? 'Чат';
    final subtitle = isDirect
        ? (_wsConnected ? 'личный чат · онлайн' : 'личный чат')
        : (_wsConnected
            ? '${displayChat.participants.length} участников · онлайн'
            : '${displayChat.participants.length} участников · кто в чате');

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            if (isDirect && dmOther != null) {
              context.push('/host/${dmOther.id}');
              return;
            }
            _showParticipants(displayChat.participants);
          },
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          if (myId != null)
            _ChatParticipantMenu(
              participants: displayChat.participants.where((p) => p.id != myId).toList(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final message = _messages[i];
                final isMe = myId != null && message.sender.id == myId;
                return _MessageBubble(message: message, isMe: isMe);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  if (!_recording) ...[
                    IconButton(
                      onPressed: _sending ? null : _showAttachSheet,
                      tooltip: 'Прикрепить',
                      icon: const Icon(Icons.attach_file),
                      color: AppColors.textSecondary,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Напишите сообщение...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    VoiceComposerControls(
                      key: _voiceKey,
                      enabled: !_sending,
                      onRecordingChanged: (v) {
                        if (mounted) setState(() => _recording = v);
                      },
                      onSend: _sendVoice,
                      onError: (msg) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                      },
                    ),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                      style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ] else
                    Expanded(
                      child: VoiceComposerControls(
                        key: _voiceKey,
                        enabled: !_sending,
                        onRecordingChanged: (v) {
                          if (mounted) setState(() => _recording = v);
                        },
                        onSend: _sendVoice,
                        onError: (msg) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  void _openSender(BuildContext context) {
    final id = message.sender.id;
    if (id.isEmpty) return;
    context.push('/host/$id');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () => _openSender(context),
              child: UserAvatar(
                url: message.sender.avatarUrl,
                size: 28,
                name: message.sender.name,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    GestureDetector(
                      onTap: () => _openSender(context),
                      child: Text(
                        message.sender.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  if (message.isVoice)
                    VoiceMessageBubble(message: message, isMe: isMe)
                  else if (message.hasAttachment)
                    ChatAttachmentContent(message: message, isMe: isMe)
                  else
                    Text(
                      message.text,
                      style: TextStyle(color: isMe ? AppColors.white : AppColors.textPrimary, fontSize: 14),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? AppColors.white.withValues(alpha: 0.7) : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Пожаловаться"/"Заблокировать" for the other chat participant(s). Chats
/// are event-scoped and can have more than 2 people, so each action is
/// shown per-participant rather than assuming a single counterpart.
class _ChatParticipantMenu extends ConsumerStatefulWidget {
  const _ChatParticipantMenu({required this.participants});

  final List<AppUser> participants;

  @override
  ConsumerState<_ChatParticipantMenu> createState() => _ChatParticipantMenuState();
}

class _ChatParticipantMenuState extends ConsumerState<_ChatParticipantMenu> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (widget.participants.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      enabled: !_busy,
      onSelected: (value) {
        final parts = value.split(':');
        final action = parts.first;
        final userId = parts.sublist(1).join(':');
        final user = widget.participants.firstWhere((p) => p.id == userId);
        if (action == 'report') {
          showReportDialog(context, ref, targetType: ComplaintTargetType.user, targetId: userId);
        } else if (action == 'block') {
          _block(user);
        }
      },
      itemBuilder: (context) => widget.participants.expand((p) => [
            PopupMenuItem(value: 'report:${p.id}', child: Text('Пожаловаться: ${p.name}')),
            PopupMenuItem(value: 'block:${p.id}', child: Text('Заблокировать: ${p.name}')),
          ]).toList(),
    );
  }

  Future<void> _block(AppUser user) async {
    setState(() => _busy = true);
    try {
      await ref.read(userRepositoryProvider).block(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} заблокирован(а)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось заблокировать'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
