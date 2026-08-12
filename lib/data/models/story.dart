import 'feed_post.dart';
import 'place.dart';

class StoryItem {
  const StoryItem({
    required this.id,
    required this.imageUrl,
    required this.createdAt,
    required this.expiresAt,
    this.videoUrl,
    this.seenByMe = false,
    this.place,
  });

  final String id;
  final String imageUrl;
  /// Short clip (boomerang / video story). Prefer over [imageUrl] in viewer.
  final String? videoUrl;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool seenByMe;
  final PlaceSummary? place;

  bool get hasVideo {
    final v = videoUrl?.trim();
    return v != null && v.isNotEmpty;
  }

  factory StoryItem.fromJson(Map<String, dynamic> json) => StoryItem(
        id: json['id'] as String,
        imageUrl: json['imageUrl'] as String,
        videoUrl: json['videoUrl'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        seenByMe: json['seenByMe'] as bool? ?? false,
        place: json['place'] is Map<String, dynamic>
            ? PlaceSummary.fromJson(json['place'] as Map<String, dynamic>)
            : null,
      );
}

class StoryGroup {
  const StoryGroup({
    required this.author,
    required this.items,
    this.hasUnseen = false,
  });

  final PostAuthor author;
  final List<StoryItem> items;
  final bool hasUnseen;

  factory StoryGroup.fromJson(Map<String, dynamic> json) => StoryGroup(
        author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
        items: (json['items'] as List<dynamic>)
            .map((e) => StoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasUnseen: json['hasUnseen'] as bool? ?? false,
      );
}
