import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config/env.dart';
import '../api/api_client.dart';
import '../mock/mock_data.dart';
import '../models/enums.dart';
import '../models/review.dart';
import '../models/user.dart';

class UserRepository {
  UserRepository(this._api);

  final ApiClient _api;

  Future<AppUser> me() async {
    if (Env.useMockData) return MockData.me;
    final res = await _api.dio.get('/users/me');
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AppUser> byId(String id) async {
    if (Env.useMockData) {
      return MockData.allUsers.firstWhere((u) => u.id == id, orElse: () => MockData.maria);
    }
    final res = await _api.dio.get('/users/$id');
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  /// Curated «Автор месяца» showcase (`GET /users/author-of-month`).
  Future<AuthorOfMonthShowcase> authorOfMonth() async {
    if (Env.useMockData) {
      return const AuthorOfMonthShowcase(period: '2026-08', periodLabel: 'август 2026');
    }
    final res = await _api.dio.get('/users/author-of-month');
    return AuthorOfMonthShowcase.fromJson(res.data as Map<String, dynamic>);
  }

  /// Matches the backend's `UpdateUserDto` - only the fields screen 10 lets
  /// the user edit (name/age/city/bio/whatICook/avatarUrl/socialLinks).
  Future<AppUser> updateProfile({
    String? name,
    int? age,
    String? city,
    String? bio,
    String? whatICook,
    String? avatarUrl,
    Map<String, String>? socialLinks,
  }) async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return MockData.me.copyWith(
        name: name,
        age: age,
        city: city,
        bio: bio,
        whatICook: whatICook,
        avatarUrl: avatarUrl,
        socialLinks: socialLinks,
      );
    }
    final res = await _api.dio.patch('/users/me', data: {
      'name': ?name,
      'age': ?age,
      'city': ?city,
      'bio': ?bio,
      'whatICook': ?whatICook,
      'avatarUrl': ?avatarUrl,
      'socialLinks': ?socialLinks,
    });
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  /// Self-serve: become PERFORMER to publish events.
  Future<AppUser> becomeOrganizer() async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      return MockData.me.copyWith(role: UserRole.performer);
    }
    final res = await _api.dio.post('/users/me/become-organizer');
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  /// Uploads one or more photos via `POST /users/me/photos` (multipart,
  /// field name "files" - matches `imageUploadOptions` on the backend: only
  /// jpg/jpeg/png/webp, 10MB max per file). Returns the updated user (with
  /// the new URLs appended to `photos`) so callers can pick the newest one
  /// as the avatar if that's what they were uploading for.
  Future<AppUser> uploadPhotos(List<File> files) async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return MockData.me;
    }
    final form = FormData.fromMap({
      'files': [
        for (final f in files) await MultipartFile.fromFile(f.path, filename: f.uri.pathSegments.last),
      ],
    });
    final res = await _api.dio.post('/users/me/photos', data: form);
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  /// Removes a photo (and clears avatarUrl too if it was the avatar -
  /// mirrors the backend's behavior).
  Future<AppUser> deletePhoto(String url) async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      final mockMe = MockData.me;
      return mockMe.copyWith(photos: mockMe.photos.where((p) => p != url).toList());
    }
    final res = await _api.dio.delete('/users/me/photos', data: {'url': url});
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  /// Permanently deletes the signed-in account on the server.
  Future<void> deleteAccount() async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _api.clearToken();
      return;
    }
    await _api.dio.delete('/users/me');
    await _api.clearToken();
  }

  Future<List<Review>> reviewsFor(String userId) async {
    if (Env.useMockData) {
      return MockData.reviews.where((r) => r.target.id == userId).toList();
    }
    final res = await _api.dio.get('/users/$userId/reviews');
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map((r) => Review.fromJson(r)).toList();
  }

  Future<void> follow(String userId) async {
    if (Env.useMockData) return;
    await _api.dio.post('/users/$userId/follow');
  }

  Future<void> unfollow(String userId) async {
    if (Env.useMockData) return;
    await _api.dio.delete('/users/$userId/follow');
  }

  Future<List<AppUser>> listFollowers(String userId) async {
    if (Env.useMockData) {
      return MockData.allUsers.where((u) => u.id != userId).take(5).toList();
    }
    final res = await _api.dio.get('/users/$userId/followers');
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map(AppUser.fromJson).toList();
  }

  Future<List<AppUser>> listFollowing(String userId) async {
    if (Env.useMockData) {
      return MockData.allUsers.where((u) => u.id != userId).take(5).toList();
    }
    final res = await _api.dio.get('/users/$userId/following');
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map(AppUser.fromJson).toList();
  }

  Future<void> block(String userId) async {
    if (Env.useMockData) return;
    await _api.dio.post('/users/$userId/block');
  }

  Future<void> unblock(String userId) async {
    if (Env.useMockData) return;
    await _api.dio.delete('/users/$userId/block');
  }

  /// Hosts available for personal requests - unique event hosts from the feed.
  Future<List<AppUser>> listCandidateHosts() async {
    if (Env.useMockData) {
      return List.of(MockData.requestCandidateHosts);
    }
    final res = await _api.dio.get('/events');
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    final byId = <String, AppUser>{};
    for (final raw in items.cast<Map<String, dynamic>>()) {
      final hostJson = raw['host'];
      if (hostJson is! Map<String, dynamic>) continue;
      final host = AppUser.fromJson(hostJson);
      byId.putIfAbsent(host.id, () => host);
    }
    final hosts = byId.values.toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return hosts;
  }
}
