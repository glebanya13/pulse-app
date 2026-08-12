class PlaceSummary {
  final String id;
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final String citySlug;
  final double ratingAvg;
  final int reviewsCount;

  const PlaceSummary({
    required this.id,
    required this.name,
    this.address,
    required this.lat,
    required this.lng,
    this.citySlug = 'minsk',
    this.ratingAvg = 0,
    this.reviewsCount = 0,
  });

  factory PlaceSummary.fromJson(Map<String, dynamic> json) => PlaceSummary(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        address: json['address'] as String?,
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        citySlug: json['citySlug'] as String? ?? 'minsk',
        ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
        reviewsCount: json['reviewsCount'] as int? ?? 0,
      );

  String get starsLabel {
    if (reviewsCount <= 0) return 'Нет отзывов';
    return '${ratingAvg.toStringAsFixed(1)} · $reviewsCount';
  }
}

class PlaceReview {
  final String id;
  final String placeId;
  final String eventId;
  final String reviewerId;
  final String? reviewerName;
  final String? reviewerAvatarUrl;
  final int stars;
  final String? comment;
  final List<String> photos;
  final DateTime createdAt;

  const PlaceReview({
    required this.id,
    required this.placeId,
    required this.eventId,
    required this.reviewerId,
    this.reviewerName,
    this.reviewerAvatarUrl,
    required this.stars,
    this.comment,
    this.photos = const [],
    required this.createdAt,
  });

  factory PlaceReview.fromJson(Map<String, dynamic> json) {
    final reviewer = json['reviewer'] as Map<String, dynamic>?;
    return PlaceReview(
      id: json['id'] as String,
      placeId: json['placeId'] as String,
      eventId: json['eventId'] as String,
      reviewerId: json['reviewerId'] as String? ?? reviewer?['id'] as String? ?? '',
      reviewerName: reviewer?['name'] as String?,
      reviewerAvatarUrl: reviewer?['avatarUrl'] as String?,
      stars: json['stars'] as int? ?? 0,
      comment: json['comment'] as String?,
      photos: (json['photos'] as List?)?.cast<String>() ?? const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class PlaceDetail {
  final PlaceSummary place;
  final List<PlaceReview> reviews;
  final List<PlaceUpcomingEvent> upcomingEvents;

  const PlaceDetail({
    required this.place,
    this.reviews = const [],
    this.upcomingEvents = const [],
  });

  factory PlaceDetail.fromJson(Map<String, dynamic> json) => PlaceDetail(
        place: PlaceSummary.fromJson(json),
        reviews: (json['reviews'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(PlaceReview.fromJson)
                .toList() ??
            const [],
        upcomingEvents: (json['events'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(PlaceUpcomingEvent.fromJson)
                .toList() ??
            const [],
      );
}

class PlaceUpcomingEvent {
  final String id;
  final String title;
  final DateTime startAt;

  const PlaceUpcomingEvent({
    required this.id,
    required this.title,
    required this.startAt,
  });

  factory PlaceUpcomingEvent.fromJson(Map<String, dynamic> json) =>
      PlaceUpcomingEvent(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        startAt: DateTime.parse(json['startAt'] as String),
      );
}
