import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Registers this device for FCM and uploads the token to our backend.
class PushNotifications {
  PushNotifications._();

  static bool _started = false;
  static void Function(String location)? _onOpenLocation;
  static void Function(Map<String, dynamic> data)? _onData;

  /// Map FCM / inbox payload → in-app route.
  static String? locationFromData(Map<String, dynamic> data) {
    final explicit = data['location']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final tab = data['tab']?.toString();
    if (tab == 'today') return '/home/events?tab=today';
    final chatId = data['chatId']?.toString();
    if (chatId != null && chatId.isNotEmpty) return '/chat/$chatId';
    final eventId = data['eventId']?.toString();
    if (eventId != null && eventId.isNotEmpty) return '/events/$eventId';
    return null;
  }

  /// Wire after [GoRouter] is ready (signed-in session).
  static void attachOpenHandler(void Function(String location) handler) {
    _onOpenLocation = handler;
  }

  /// Invalidate Riverpod caches when push data arrives (foreground / opened).
  static void attachDataHandler(void Function(Map<String, dynamic> data) handler) {
    _onData = handler;
  }

  static void _openFromMessage(RemoteMessage message) {
    _onData?.call(message.data);
    final location = locationFromData(message.data);
    if (location == null) return;
    _onOpenLocation?.call(location);
  }

  /// Call once after Firebase.initializeApp (and again after login).
  static Future<void> syncTokenWithBackend(ApiClient api) async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;

      if (!_started) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        FirebaseMessaging.onMessage.listen((message) {
          debugPrint(
            'FCM foreground: ${message.notification?.title} ${message.notification?.body}',
          );
          _onData?.call(message.data);
        });
        FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
        final initial = await messaging.getInitialMessage();
        if (initial != null) {
          Future<void>.delayed(const Duration(milliseconds: 400), () {
            _openFromMessage(initial);
          });
        }
        _started = true;
      }

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      await api.dio.put('/users/me/fcm-token', data: {'token': token});

      messaging.onTokenRefresh.listen((newToken) async {
        try {
          await api.dio.put('/users/me/fcm-token', data: {'token': newToken});
        } catch (e) {
          debugPrint('FCM token refresh upload failed: $e');
        }
      });
    } catch (e, st) {
      debugPrint('FCM sync skipped: $e\n$st');
    }
  }

  static Future<void> clearBackendToken(ApiClient api) async {
    try {
      await api.dio.put('/users/me/fcm-token', data: {'token': null});
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (e) {
      debugPrint('FCM clear skipped: $e');
    }
  }
}
