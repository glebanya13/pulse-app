import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config/env.dart';
import '../api/api_client.dart';
import '../mock/mock_data.dart';
import '../models/chat.dart';
import '../models/user.dart';

class ChatRepository {
  ChatRepository(this._api) : _chats = List.of(MockData.chats);

  final ApiClient _api;
  final List<Chat> _chats;

  Future<List<Chat>> list() async {
    if (Env.useMockData) return List.of(_chats);
    final res = await _api.dio.get('/chats');
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items
        .cast<Map<String, dynamic>>()
        .map((c) => Chat.fromJson(c, messagesNewestFirst: true))
        .toList();
  }

  Future<int> unreadTotal() async {
    if (Env.useMockData) {
      return _chats.fold<int>(0, (sum, c) => sum + c.unreadCount);
    }
    final res = await _api.dio.get('/chats/unread-count');
    return (res.data as Map<String, dynamic>)['unreadTotal'] as int? ?? 0;
  }

  /// Preferred path for opening a chat from an event screen - does not depend
  /// on successfully parsing every other chat preview in `/chats`.
  Future<Chat?> byEventId(String eventId) async {
    if (Env.useMockData) {
      try {
        return _chats.firstWhere((c) => c.event?.id == eventId);
      } catch (_) {
        return null;
      }
    }
    try {
      final res = await _api.dio.get('/chats/by-event/$eventId');
      return Chat.fromJson(res.data as Map<String, dynamic>, messagesNewestFirst: true);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Open or create a 1:1 direct chat with [userId].
  Future<Chat> createDm(String userId) async {
    if (Env.useMockData) {
      final existing = _chats.where(
        (c) => c.isDirect && c.participants.any((p) => p.id == userId),
      );
      if (existing.isNotEmpty) return existing.first;
      final other = MockData.allUsers.firstWhere(
        (u) => u.id == userId,
        orElse: () => MockData.maria,
      );
      final chat = Chat(
        id: 'dm_${DateTime.now().microsecondsSinceEpoch}',
        participants: [MockData.me, other],
        isDirect: true,
      );
      _chats.insert(0, chat);
      return chat;
    }
    final res = await _api.dio.post('/chats/dm', data: {'userId': userId});
    return Chat.fromJson(res.data as Map<String, dynamic>, messagesNewestFirst: true);
  }

  /// Combines optional list metadata with paginated message history.
  Future<Chat> byId(String id) async {
    if (Env.useMockData) return _chats.firstWhere((c) => c.id == id);

    Chat shell = Chat(id: id);
    try {
      final chats = await list();
      shell = chats.firstWhere((c) => c.id == id, orElse: () => Chat(id: id));
    } catch (_) {
      // Keep bare shell - messages endpoint is enough to render the thread.
    }

    final res = await _api.dio.get('/chats/$id/messages', queryParameters: {'limit': 200});
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    final messages = items
        .cast<Map<String, dynamic>>()
        .map((m) => ChatMessage.fromJson(m, fallbackChatId: id))
        .toList()
        .reversed
        .toList();

    return Chat(
      id: id,
      event: shell.event,
      participants: shell.participants,
      messages: messages,
      unreadCount: 0,
      isDirect: shell.isDirect,
    );
  }

  Future<List<ChatMessage>> messages(String chatId) async {
    if (Env.useMockData) {
      final chat = _chats.firstWhere((c) => c.id == chatId, orElse: () => Chat(id: chatId));
      return chat.messages;
    }
    final res = await _api.dio.get('/chats/$chatId/messages', queryParameters: {'limit': 200});
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items
        .cast<Map<String, dynamic>>()
        .map((m) => ChatMessage.fromJson(m, fallbackChatId: chatId))
        .toList()
        .reversed
        .toList();
  }

  Future<ChatMessage> sendMessage(String chatId, AppUser sender, String text) async {
    if (Env.useMockData) {
      final message = ChatMessage(
        id: 'm_${DateTime.now().microsecondsSinceEpoch}',
        chatId: chatId,
        sender: sender,
        text: text,
        createdAt: DateTime.now(),
      );
      final idx = _chats.indexWhere((c) => c.id == chatId);
      if (idx != -1) {
        final c = _chats[idx];
        _chats[idx] = c.copyWith(messages: [...c.messages, message]);
      }
      return message;
    }
    final res = await _api.dio.post('/chats/$chatId/messages', data: {'text': text});
    return ChatMessage.fromJson(res.data as Map<String, dynamic>, fallbackChatId: chatId);
  }

  Future<ChatMessage> sendVoice({
    required String chatId,
    required AppUser sender,
    required File file,
    required int durationMs,
  }) async {
    if (Env.useMockData) {
      final message = ChatMessage(
        id: 'm_${DateTime.now().microsecondsSinceEpoch}',
        chatId: chatId,
        sender: sender,
        audioUrl: file.path,
        durationMs: durationMs,
        createdAt: DateTime.now(),
      );
      final idx = _chats.indexWhere((c) => c.id == chatId);
      if (idx != -1) {
        final c = _chats[idx];
        _chats[idx] = c.copyWith(messages: [...c.messages, message]);
      }
      return message;
    }
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.isEmpty ? 'voice.m4a' : file.uri.pathSegments.last,
      ),
      'durationMs': durationMs,
    });
    final res = await _api.dio.post('/chats/$chatId/messages/voice', data: form);
    return ChatMessage.fromJson(res.data as Map<String, dynamic>, fallbackChatId: chatId);
  }

  Future<ChatMessage> sendAttachment({
    required String chatId,
    required AppUser sender,
    required File file,
    String? caption,
    String? filename,
  }) async {
    final name = filename ??
        (file.uri.pathSegments.isEmpty ? 'file' : file.uri.pathSegments.last);
    if (Env.useMockData) {
      final lower = name.toLowerCase();
      final isImage = lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp');
      final message = ChatMessage(
        id: 'm_${DateTime.now().microsecondsSinceEpoch}',
        chatId: chatId,
        sender: sender,
        text: caption ?? '',
        attachmentUrl: file.path,
        attachmentName: name,
        attachmentMime: isImage ? 'image/jpeg' : 'application/octet-stream',
        createdAt: DateTime.now(),
      );
      final idx = _chats.indexWhere((c) => c.id == chatId);
      if (idx != -1) {
        final c = _chats[idx];
        _chats[idx] = c.copyWith(messages: [...c.messages, message]);
      }
      return message;
    }
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: name),
      if (caption != null && caption.trim().isNotEmpty) 'text': caption.trim(),
    });
    final res = await _api.dio.post('/chats/$chatId/messages/attachment', data: form);
    return ChatMessage.fromJson(res.data as Map<String, dynamic>, fallbackChatId: chatId);
  }

  Future<void> markRead(String chatId) async {
    if (Env.useMockData) return;
    await _api.dio.post('/chats/$chatId/read');
  }
}
