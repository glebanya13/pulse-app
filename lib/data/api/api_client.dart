import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/env.dart';

/// Thin Dio wrapper with JWT attach + silent refresh on 401.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Refresh calls must not carry a stale Authorization header.
          if (options.extra['skipAuth'] == true) {
            handler.next(options);
            return;
          }
          final token = await _readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode != 401 ||
              error.requestOptions.extra['skipAuth'] == true ||
              error.requestOptions.extra['retried'] == true) {
            handler.next(error);
            return;
          }

          final refreshed = await _tryRefresh();
          if (!refreshed) {
            await clearTokens();
            onUnauthorized?.call();
            handler.next(error);
            return;
          }

          try {
            final opts = error.requestOptions;
            opts.extra['retried'] = true;
            final access = await _readAccessToken();
            if (access != null) {
              opts.headers['Authorization'] = 'Bearer $access';
            }
            // FormData (photo/avatar uploads) is a one-shot stream - the
            // first (failed) request already consumed it, so retrying with
            // the same instance throws "FormData has already been
            // finalized". Clone it before resending.
            final body = opts.data;
            if (body is FormData) {
              opts.data = body.clone();
            }
            final response = await _dio.fetch(opts);
            handler.resolve(response);
          } catch (e) {
            if (e is DioException) {
              handler.next(e);
            } else {
              handler.next(error);
            }
          }
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;
  Future<bool>? _refreshInFlight;

  Dio get dio => _dio;

  /// Wired up once at app startup (see main.dart) to sign the user out -
  /// go_router's redirect then sends them back to /welcome.
  void Function()? onUnauthorized;

  static const _accessTokenKey = 'pulse_access_token';
  static const _refreshTokenKey = 'pulse_refresh_token';

  Future<String?> _readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> _readRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<String?> readAccessToken() => _readAccessToken();

  Future<String?> readRefreshToken() => _readRefreshToken();

  Future<bool> hasToken() async => (await _readAccessToken()) != null;

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
  }

  /// Backward-compatible alias used by older call sites.
  Future<void> saveToken(String token) => saveTokens(accessToken: token);

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  /// Backward-compatible alias.
  Future<void> clearToken() => clearTokens();

  Future<bool> _tryRefresh() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _doRefresh() async {
    final refresh = await _readRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refresh},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = res.data as Map<String, dynamic>;
      final access = data['accessToken'] as String?;
      final nextRefresh = data['refreshToken'] as String?;
      if (access == null || access.isEmpty) return false;
      await saveTokens(accessToken: access, refreshToken: nextRefresh ?? refresh);
      return true;
    } catch (_) {
      return false;
    }
  }
}
