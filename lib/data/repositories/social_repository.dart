import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config/env.dart';
import '../api/api_client.dart';
import '../models/feed_post.dart';
import '../models/story.dart';

class SocialRepository {
  SocialRepository(this._api);

  final ApiClient _api;

  Future<List<FeedPost>> listPosts({String? authorId}) async {
    final res = await _api.dio.get(
      '/posts',
      queryParameters: {
        if (authorId != null) 'authorId': authorId,
      },
    );
    final list = res.data as List<dynamic>;
    return list.map((e) => FeedPost.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FeedPost>> listSavedPosts() async {
    final res = await _api.dio.get('/posts/saved');
    final list = res.data as List<dynamic>;
    return list.map((e) => FeedPost.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FeedPost> createPost({
    required String imageUrl,
    String? caption,
    String? placeId,
  }) async {
    final res = await _api.dio.post('/posts', data: {
      'imageUrl': imageUrl,
      if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
      if (placeId != null) 'placeId': placeId,
    });
    return FeedPost.fromJson(res.data as Map<String, dynamic>);
  }

  Future<String> uploadImage(File file) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
    });
    final res = await _api.dio.post('/posts/upload', data: form);
    final url = res.data['url'] as String;
    return Env.resolveMediaUrl(url);
  }

  /// Returns path suitable for API body (prefer relative /uploads/...).
  Future<String> uploadImagePath(File file) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
    });
    final res = await _api.dio.post('/posts/upload', data: form);
    return res.data['url'] as String;
  }

  Future<String> uploadVideoPath(File file) async {
    final name = file.uri.pathSegments.isEmpty
        ? 'story.mp4'
        : file.uri.pathSegments.last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: name),
    });
    final res = await _api.dio.post('/stories/upload-video', data: form);
    return res.data['url'] as String;
  }

  Future<({bool liked, int likesCount})> like(String postId) async {
    final res = await _api.dio.post('/posts/$postId/like');
    return (
      liked: res.data['liked'] as bool? ?? true,
      likesCount: res.data['likesCount'] as int? ?? 0,
    );
  }

  Future<({bool liked, int likesCount})> unlike(String postId) async {
    final res = await _api.dio.delete('/posts/$postId/like');
    return (
      liked: res.data['liked'] as bool? ?? false,
      likesCount: res.data['likesCount'] as int? ?? 0,
    );
  }

  Future<bool> save(String postId) async {
    final res = await _api.dio.post('/posts/$postId/save');
    return res.data['saved'] as bool? ?? true;
  }

  Future<bool> unsave(String postId) async {
    final res = await _api.dio.delete('/posts/$postId/save');
    return res.data['saved'] as bool? ?? false;
  }

  Future<List<PostComment>> listComments(String postId) async {
    final res = await _api.dio.get('/posts/$postId/comments');
    final list = res.data as List<dynamic>;
    return list.map((e) => PostComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<({PostComment comment, int commentsCount})> addComment(
    String postId,
    String text,
  ) async {
    final res = await _api.dio.post('/posts/$postId/comments', data: {'text': text});
    return (
      comment: PostComment.fromJson(res.data['comment'] as Map<String, dynamic>),
      commentsCount: res.data['commentsCount'] as int? ?? 0,
    );
  }

  Future<void> deletePost(String postId) async {
    await _api.dio.delete('/posts/$postId');
  }

  Future<List<StoryGroup>> storiesFeed() async {
    final res = await _api.dio.get('/stories/feed');
    final list = res.data as List<dynamic>;
    return list.map((e) => StoryGroup.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createStory({
    required String imageUrl,
    String? placeId,
    String? videoUrl,
  }) async {
    await _api.dio.post('/stories', data: {
      'imageUrl': imageUrl,
      if (placeId != null) 'placeId': placeId,
      if (videoUrl != null && videoUrl.isNotEmpty) 'videoUrl': videoUrl,
    });
  }

  Future<void> viewStory(String storyId) async {
    await _api.dio.post('/stories/$storyId/view');
  }
}
