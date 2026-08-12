import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/config/env.dart';
import '../api/api_client.dart';
import '../models/chat.dart';

/// Realtime chat over Socket.IO (`namespace /chat`).
///
/// Auth: access JWT in handshake `auth.token`.
/// Events: client `join`/`leave`, server `message:new`.
class ChatSocket {
  ChatSocket({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;
  io.Socket? _socket;
  String? _joinedChatId;
  void Function(ChatMessage message)? onMessage;
  void Function(bool connected)? onConnectionChanged;

  bool get isConnected => _socket?.connected == true;

  Future<void> connect() async {
    if (Env.useMockData) return;

    final token = await _api.readAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('ChatSocket: no access token');
      return;
    }

    await disconnect();

    final socket = io.io(
      '${Env.apiOrigin}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setReconnectionAttempts(50)
          .setReconnectionDelay(1000)
          .setAuth({'token': token})
          .build(),
    );

    socket.onConnect((_) {
      debugPrint('ChatSocket: connected');
      onConnectionChanged?.call(true);
      final chatId = _joinedChatId;
      if (chatId != null) {
        socket.emit('join', {'chatId': chatId});
      }
    });

    socket.onDisconnect((_) {
      debugPrint('ChatSocket: disconnected');
      onConnectionChanged?.call(false);
    });

    socket.onConnectError((err) {
      debugPrint('ChatSocket: connect_error $err');
      onConnectionChanged?.call(false);
    });

    socket.on('message:new', (data) {
      try {
        if (data is! Map) return;
        final map = Map<String, dynamic>.from(data);
        final message = ChatMessage.fromJson(map);
        if (_joinedChatId != null &&
            message.chatId.isNotEmpty &&
            message.chatId != _joinedChatId) {
          return;
        }
        onMessage?.call(message);
      } catch (e, st) {
        debugPrint('ChatSocket: bad message:new $e\n$st');
      }
    });

    _socket = socket;
    socket.connect();
  }

  void join(String chatId) {
    _joinedChatId = chatId;
    if (_socket?.connected == true) {
      _socket!.emit('join', {'chatId': chatId});
    }
  }

  void leave(String chatId) {
    if (_joinedChatId == chatId) _joinedChatId = null;
    if (_socket?.connected == true) {
      _socket!.emit('leave', {'chatId': chatId});
    }
  }

  /// Refresh JWT after token rotation and reconnect.
  Future<void> reconnectWithFreshToken() async {
    final chatId = _joinedChatId;
    await connect();
    if (chatId != null) join(chatId);
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    if (socket == null) return;
    try {
      socket.clearListeners();
      socket.disconnect();
      socket.dispose();
    } catch (e) {
      debugPrint('ChatSocket: disconnect $e');
    }
  }
}
