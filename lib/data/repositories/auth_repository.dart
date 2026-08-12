import 'package:dio/dio.dart';

import '../../core/config/env.dart';
import '../api/api_client.dart';
import '../mock/mock_data.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// Requests an SMS code for [phone]. In mock mode the "code" is always
  /// 0000, matching the backend's dev-mode stub.
  Future<void> requestCode(String phone) async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }
    await _api.dio.post('/auth/request-code', data: {'phone': phone});
  }

  Future<AppUser> verifyCode(String phone, String code) async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (code != '0000') {
        throw Exception('Неверный код');
      }
      await _api.saveTokens(accessToken: 'mock-token', refreshToken: 'mock-refresh');
      return MockData.me;
    }
    final response = await _api.dio.post('/auth/verify-code', data: {
      'phone': phone,
      'code': code,
    });
    return _persistSession(response.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    if (!Env.useMockData) {
      final refresh = await _api.readRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        try {
          await _api.dio.post(
            '/auth/logout',
            data: {'refreshToken': refresh},
            options: Options(extra: {'skipAuth': true}),
          );
        } catch (_) {
          // Local logout still proceeds.
        }
      }
    }
    await _api.clearTokens();
  }

  /// Starts the "log in with Telegram" flow.
  Future<TelegramLoginSession> startTelegramLogin([String? phone]) async {
    final response = await _api.dio.post('/auth/telegram/start', data: {'phone': ?phone});
    final data = response.data as Map<String, dynamic>;
    return TelegramLoginSession(
      sessionId: data['sessionId'] as String,
      deepLink: data['deepLink'] as String,
    );
  }

  Future<TelegramLoginStatus> pollTelegramLogin(String sessionId) async {
    final response = await _api.dio.get('/auth/telegram/status/$sessionId');
    return _parseLoginStatus(response.data as Map<String, dynamic>);
  }

  Future<OAuthLoginSession> startOAuthLogin(String provider) async {
    final response = await _api.dio.post('/auth/$provider/start');
    final data = response.data as Map<String, dynamic>;
    return OAuthLoginSession(
      sessionId: data['sessionId'] as String,
      authorizeUrl: data['authorizeUrl'] as String,
    );
  }

  Future<TelegramLoginStatus> pollOAuthLogin(String provider, String sessionId) async {
    final response = await _api.dio.get('/auth/$provider/status/$sessionId');
    return _parseLoginStatus(response.data as Map<String, dynamic>);
  }

  /// Exchanges a Firebase Auth ID token for our own JWT pair. [name] is
  /// forwarded when the IdP's native SDK returned one out-of-band (Apple
  /// only puts it in the identity token's claims never - it comes from
  /// AppleIDCredential.givenName/familyName on the first authorization only).
  Future<AppUser> loginWithFirebaseIdToken(
    String idToken, {
    String? name,
    String? appleAuthorizationCode,
  }) async {
    final response = await _api.dio.post('/auth/firebase', data: {
      'idToken': idToken,
      if (name != null && name.isNotEmpty) 'name': name,
      if (appleAuthorizationCode != null && appleAuthorizationCode.isNotEmpty)
        'appleAuthorizationCode': appleAuthorizationCode,
    });
    return _persistSession(response.data as Map<String, dynamic>);
  }

  Future<AppUser> _persistSession(Map<String, dynamic> data) async {
    await _api.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String?,
    );
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<TelegramLoginStatus> _parseLoginStatus(Map<String, dynamic> data) async {
    final status = data['status'] as String;
    if (status == 'VERIFIED') {
      final user = await _persistSession(data);
      return TelegramLoginStatus.verified(user);
    }
    if (status == 'EXPIRED') {
      return TelegramLoginStatus.expired();
    }
    return TelegramLoginStatus.pending();
  }
}

class OAuthLoginSession {
  final String sessionId;
  final String authorizeUrl;

  const OAuthLoginSession({required this.sessionId, required this.authorizeUrl});
}

class TelegramLoginSession {
  final String sessionId;
  final String deepLink;

  const TelegramLoginSession({required this.sessionId, required this.deepLink});
}

class TelegramLoginStatus {
  final bool isVerified;
  final bool isExpired;
  final AppUser? user;

  const TelegramLoginStatus._({required this.isVerified, required this.isExpired, this.user});

  factory TelegramLoginStatus.verified(AppUser user) =>
      TelegramLoginStatus._(isVerified: true, isExpired: false, user: user);
  factory TelegramLoginStatus.expired() => const TelegramLoginStatus._(isVerified: false, isExpired: true);
  factory TelegramLoginStatus.pending() => const TelegramLoginStatus._(isVerified: false, isExpired: false);
}
