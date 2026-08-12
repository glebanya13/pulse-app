import 'event.dart';
import 'user.dart';

class ChatMessage {
  final String id;
  final String chatId;
  final AppUser sender;
  final String text;
  final String? audioUrl;
  final int? durationMs;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMime;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.sender,
    this.text = '',
    this.audioUrl,
    this.durationMs,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMime,
    required this.createdAt,
  });

  bool get isVoice => audioUrl != null && audioUrl!.isNotEmpty;

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;

  bool get isImageAttachment {
    if (!hasAttachment) return false;
    final mime = (attachmentMime ?? '').toLowerCase();
    if (mime.startsWith('image/')) return true;
    final name = (attachmentName ?? attachmentUrl ?? '').toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.heic') ||
        name.endsWith('.heif') ||
        name.endsWith('.gif');
  }

  String get previewText {
    if (isVoice) {
      final sec = ((durationMs ?? 0) / 1000).round();
      return sec > 0 ? 'Голосовое · $sec с' : 'Голосовое сообщение';
    }
    if (isImageAttachment) {
      return text.isNotEmpty ? 'Фото: $text' : 'Фото';
    }
    if (hasAttachment) {
      final name = attachmentName ?? 'Файл';
      return text.isNotEmpty ? '$name · $text' : name;
    }
    return text;
  }

  String get durationLabel {
    final totalSec = ((durationMs ?? 0) / 1000).round().clamp(0, 9999);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? fallbackChatId}) {
    final senderJson = json['sender'] as Map<String, dynamic>?;
    final sender = senderJson != null
        ? AppUser.fromJson(senderJson)
        : AppUser(
            id: json['senderId'] as String? ?? '',
            name: 'Участник',
            age: 0,
            city: '',
            memberSince: DateTime.now(),
          );
    return ChatMessage(
      id: json['id'] as String,
      chatId: json['chatId'] as String? ?? fallbackChatId ?? '',
      sender: sender,
      text: json['text'] as String? ?? '',
      audioUrl: json['audioUrl'] as String?,
      durationMs: json['durationMs'] as int?,
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentName: json['attachmentName'] as String?,
      attachmentMime: json['attachmentMime'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class Chat {
  final String id;
  final Event? event;
  final List<AppUser> participants;
  final List<ChatMessage> messages;
  final int unreadCount;
  final bool isDirect;

  const Chat({
    required this.id,
    this.event,
    this.participants = const [],
    this.messages = const [],
    this.unreadCount = 0,
    this.isDirect = false,
  });

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  String titleFor(String? myUserId) {
    if (event != null) return event!.title;
    if (isDirect || event == null) {
      final other = participants.where((p) => p.id != myUserId);
      if (other.isNotEmpty) return other.first.name;
    }
    return 'Чат';
  }

  Chat copyWith({int? unreadCount, List<ChatMessage>? messages, bool? isDirect}) => Chat(
        id: id,
        event: event,
        participants: participants,
        messages: messages ?? this.messages,
        unreadCount: unreadCount ?? this.unreadCount,
        isDirect: isDirect ?? this.isDirect,
      );

  factory Chat.fromJson(Map<String, dynamic> json, {bool messagesNewestFirst = false}) {
    final rawMessages = (json['messages'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map((m) => ChatMessage.fromJson(m, fallbackChatId: json['id'] as String?))
            .toList() ??
        const [];
    final event = json['event'] != null ? Event.fromJson(json['event'] as Map<String, dynamic>) : null;
    final isDirect = json['isDirect'] as bool? ?? (json['eventId'] == null && event == null);
    return Chat(
      id: json['id'] as String,
      event: event,
      participants: (json['participants'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map((p) {
                final userJson = p['user'];
                if (userJson is Map<String, dynamic>) {
                  return AppUser.fromJson(userJson);
                }
                return AppUser.fromJson(p);
              })
              .toList() ??
          const [],
      messages: messagesNewestFirst ? rawMessages.reversed.toList() : rawMessages,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isDirect: isDirect,
    );
  }
}
