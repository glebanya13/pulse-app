import 'place.dart';

class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.city = '',
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final String city;

  factory PostAuthor.fromJson(Map<String, dynamic> json) => PostAuthor(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
        city: json['city'] as String? ?? '',
      );
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorId,
    required this.imageUrl,
    required this.createdAt,
    required this.author,
    this.caption,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedByMe = false,
    this.savedByMe = false,
    this.place,
  });

  final String id;
  final String authorId;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final bool savedByMe;
  final PostAuthor author;
  final PlaceSummary? place;

  factory FeedPost.fromJson(Map<String, dynamic> json) => FeedPost(
        id: json['id'] as String,
        authorId: json['authorId'] as String,
        imageUrl: json['imageUrl'] as String,
        caption: json['caption'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        likesCount: json['likesCount'] as int? ?? 0,
        commentsCount: json['commentsCount'] as int? ?? 0,
        likedByMe: json['likedByMe'] as bool? ?? false,
        savedByMe: json['savedByMe'] as bool? ?? false,
        author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
        place: json['place'] is Map<String, dynamic>
            ? PlaceSummary.fromJson(json['place'] as Map<String, dynamic>)
            : null,
      );

  FeedPost copyWith({
    int? likesCount,
    int? commentsCount,
    bool? likedByMe,
    bool? savedByMe,
  }) =>
      FeedPost(
        id: id,
        authorId: authorId,
        imageUrl: imageUrl,
        caption: caption,
        createdAt: createdAt,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
        author: author,
        place: place,
      );
}

class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.text,
    required this.createdAt,
    required this.author,
  });

  final String id;
  final String postId;
  final String text;
  final DateTime createdAt;
  final PostAuthor author;

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: json['id'] as String,
        postId: json['postId'] as String,
        text: json['text'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
      );
}
