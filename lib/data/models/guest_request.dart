import 'enums.dart';
import 'user.dart';

class RequestOffer {
  final String id;
  final AppUser host;
  final OfferStatus status;
  final String? message;
  final DateTime createdAt;

  const RequestOffer({
    required this.id,
    required this.host,
    this.status = OfferStatus.pending,
    this.message,
    required this.createdAt,
  });

  /// `GET /requests/:id` embeds the offering host; other endpoints that
  /// return bare `RequestOffer` rows (e.g. "my requests") don't - pass
  /// [fallbackHost] there if it's known, otherwise a placeholder is used
  /// rather than crashing.
  factory RequestOffer.fromJson(Map<String, dynamic> json, {AppUser? fallbackHost}) {
    final hostJson = json['host'] as Map<String, dynamic>?;
    return RequestOffer(
      id: json['id'] as String,
      host: hostJson != null
          ? AppUser.fromJson(hostJson)
          : fallbackHost ??
              AppUser(id: json['hostId'] as String? ?? '', name: '', age: 0, city: '', memberSince: DateTime.now()),
      status: OfferStatus.fromBackend(json['status'] as String),
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class GuestRequest {
  final String id;
  final AppUser author;
  final RequestType type;
  final String title;
  final String description;
  final int? portionsCount;
  final PriceType budgetType;
  final double? budgetAmount;
  final DateTime requestedAt;
  final DateTime? requestedEndAt;
  final AppUser? targetHost;
  final RequestStatus status;
  final DateTime createdAt;
  final String? address;
  final List<RequestOffer> offers;
  final List<String> photos;

  const GuestRequest({
    required this.id,
    required this.author,
    required this.type,
    required this.title,
    required this.description,
    this.portionsCount,
    this.budgetType = PriceType.free,
    this.budgetAmount,
    required this.requestedAt,
    this.requestedEndAt,
    this.targetHost,
    this.status = RequestStatus.open,
    required this.createdAt,
    this.address,
    this.offers = const [],
    this.photos = const [],
  });

  String get budgetLabel => switch (budgetType) {
        PriceType.free => 'Любой',
        PriceType.fixed => 'до ${budgetAmount?.toInt() ?? 0} ₽',
        PriceType.donation => 'Донат',
      };

  String? get coverPhoto => photos.isNotEmpty ? photos.first : null;

  /// [fallbackAuthor] covers `GET /requests/:eventId/applications`-style
  /// endpoints that don't embed the author (none currently do, but this
  /// mirrors the defensive pattern used across the other models so a future
  /// backend response shape change degrades gracefully instead of crashing).
  factory GuestRequest.fromJson(Map<String, dynamic> json, {AppUser? fallbackAuthor}) {
    final authorJson = json['author'] as Map<String, dynamic>?;
    return GuestRequest(
      id: json['id'] as String,
      author: authorJson != null
          ? AppUser.fromJson(authorJson)
          : fallbackAuthor ??
              AppUser(id: json['authorId'] as String? ?? '', name: '', age: 0, city: '', memberSince: DateTime.now()),
      type: RequestType.fromBackend(json['type'] as String),
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      portionsCount: json['portionsCount'] as int?,
      budgetType: PriceType.fromBackend(json['budgetType'] as String? ?? 'FREE'),
      budgetAmount: (json['budgetAmount'] as num?)?.toDouble(),
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      requestedEndAt: json['requestedEndAt'] != null
          ? DateTime.parse(json['requestedEndAt'] as String)
          : null,
      // The backend never embeds a `targetHost` object, only `targetHostId`
      // - resolving it would need an extra per-item fetch, so callers that
      // need the name (e.g. "Предложено: <host>") fall back to showing the
      // offer count instead when this is null.
      targetHost: null,
      status: RequestStatus.fromBackend(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      address: json['address'] as String?,
      offers: (json['offers'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map((o) => RequestOffer.fromJson(o))
              .toList() ??
          const [],
      photos: (json['photos'] as List?)?.cast<String>() ?? const [],
    );
  }
}
