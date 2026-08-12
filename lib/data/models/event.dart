import 'enums.dart';
import 'place.dart';
import 'user.dart';

class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint({required this.latitude, required this.longitude});
}

class GuestRequirements {
  final GenderFilter gender;
  final int? minAge;
  final int? maxAge;
  final List<String> interests;

  const GuestRequirements({
    this.gender = GenderFilter.any,
    this.minAge,
    this.maxAge,
    this.interests = const [],
  });

  String get summary {
    if (gender == GenderFilter.any && minAge == null && maxAge == null) {
      return 'Все';
    }
    final parts = <String>[];
    if (gender != GenderFilter.any) parts.add(gender.label);
    if (minAge != null || maxAge != null) {
      parts.add('${minAge ?? 0}-${maxAge ?? 99} лет');
    }
    return parts.join(', ');
  }

  /// The backend keeps these as flat `requirement*` fields on Event rather
  /// than a nested object.
  factory GuestRequirements.fromEventJson(Map<String, dynamic> json) => GuestRequirements(
        gender: json['requirementGender'] != null
            ? GenderFilter.fromBackend(json['requirementGender'] as String)
            : GenderFilter.any,
        minAge: json['requirementMinAge'] as int?,
        maxAge: json['requirementMaxAge'] as int?,
        interests: (json['requirementInterests'] as List?)?.cast<String>() ?? const [],
      );

  Map<String, dynamic> toEventJson() => {
        'requirementGender': gender.backend,
        'requirementMinAge': minAge,
        'requirementMaxAge': maxAge,
        'requirementInterests': interests,
      };
}

class FriendGoing {
  final String id;
  final String name;
  final String? avatarUrl;

  const FriendGoing({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory FriendGoing.fromJson(Map<String, dynamic> json) => FriendGoing(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class EventStats {
  final int viewCount;
  final int applicationsCount;
  final int acceptedCount;
  final bool isBoosted;
  final DateTime? boostedUntil;
  final int currentGuestsCount;

  const EventStats({
    required this.viewCount,
    required this.applicationsCount,
    required this.acceptedCount,
    required this.isBoosted,
    this.boostedUntil,
    required this.currentGuestsCount,
  });

  factory EventStats.fromJson(Map<String, dynamic> json) => EventStats(
        viewCount: json['viewCount'] as int? ?? 0,
        applicationsCount: json['applicationsCount'] as int? ?? 0,
        acceptedCount: json['acceptedCount'] as int? ?? 0,
        isBoosted: json['isBoosted'] as bool? ?? false,
        boostedUntil: json['boostedUntil'] != null
            ? DateTime.parse(json['boostedUntil'] as String)
            : null,
        currentGuestsCount: json['currentGuestsCount'] as int? ?? 0,
      );
}

class Event {
  final String id;
  final AppUser host;
  final EventFormat format;
  final String title;
  final String description;
  final List<String> photos;
  final List<String> tags;
  final DateTime startAt;
  /// End of “waiting for guests” window; null = point-in-time (legacy).
  final DateTime? endAt;
  final String address;
  final GeoPoint location;
  final int minGuests;
  final int maxGuests;
  final int currentGuests;
  final PriceType priceType;
  final double? priceAmount;
  final GuestRequirements requirements;
  final PickupMethod? pickupMethod;
  final String? pickupAddress;
  final int? portionWeightGrams;
  final EventStatus status;
  final bool isFavorite;
  /// Present when the current user is already a chat participant for this event.
  final String? chatId;
  final DateTime? boostedUntil;
  final bool isBoosted;
  final String citySlug;
  final List<FriendGoing> friendsGoing;
  final int friendsGoingCount;
  final int viewCount;
  /// Admin-only hint when auto-moderation flagged the event.
  final String? moderationNote;
  final PlaceSummary? place;
  final String? placeName;

  const Event({
    required this.id,
    required this.host,
    required this.format,
    required this.title,
    required this.description,
    this.photos = const [],
    this.tags = const [],
    required this.startAt,
    this.endAt,
    required this.address,
    required this.location,
    this.minGuests = 1,
    this.maxGuests = 1,
    this.currentGuests = 0,
    this.priceType = PriceType.free,
    this.priceAmount,
    this.requirements = const GuestRequirements(),
    this.pickupMethod,
    this.pickupAddress,
    this.portionWeightGrams,
    this.status = EventStatus.active,
    this.isFavorite = false,
    this.chatId,
    this.boostedUntil,
    this.isBoosted = false,
    this.citySlug = 'minsk',
    this.friendsGoing = const [],
    this.friendsGoingCount = 0,
    this.viewCount = 0,
    this.moderationNote,
    this.place,
    this.placeName,
  });

  bool get isActivelyBoosted {
    if (isBoosted) return true;
    final until = boostedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  bool get isTakeaway => format == EventFormat.takeaway;

  /// Effective end of the waiting window.
  DateTime get windowEnd => endAt ?? startAt;

  String get priceLabel => switch (priceType) {
        PriceType.free => 'Бесплатно',
        PriceType.fixed => '${priceAmount?.toInt() ?? 0} ₽',
        PriceType.donation => 'Донат',
      };

  /// Capacity range, e.g. "2-6". Same numbers collapse to one.
  String get guestsRangeLabel =>
      minGuests == maxGuests ? '$maxGuests' : '$minGuests-$maxGuests';

  /// Soft start: enough accepted guests to begin cooking.
  bool get thresholdReached => currentGuests >= minGuests;

  int get guestsNeededForStart =>
      thresholdReached ? 0 : (minGuests - currentGuests);

  /// Cover badge: max seats only (min is the start threshold, not capacity).
  String get seatsBadgeLabel => isTakeaway ? '$maxGuests порц.' : 'до $maxGuests';

  /// "7/8 - ещё 1" or "Набралось · 8/12 мест"
  String get thresholdLabel {
    if (isTakeaway) return spotsLabel;
    if (thresholdReached) {
      return 'Набралось · $currentGuests/$maxGuests мест';
    }
    return 'Набор $currentGuests/$minGuests · ещё $guestsNeededForStart';
  }

  bool get isOpenForApplications =>
      status == EventStatus.active && currentGuests < maxGuests;

  String get applyBlockedReason {
    if (status == EventStatus.cancelled) return 'Событие отменено';
    if (status == EventStatus.completed) return 'Окно уже закрыто';
    if (status == EventStatus.pendingReview) return 'На проверке';
    if (currentGuests >= maxGuests) {
      return isTakeaway ? 'Порций больше нет' : 'Мест больше нет';
    }
    return '';
  }

  String get spotsLabel =>
      isTakeaway ? '$currentGuests/$maxGuests порций' : '$currentGuests/$maxGuests мест';

  /// Social line for cards: «12 идут · 2 друга».
  String get goingSocialLabel {
    final going = currentGuests;
    final goingPart = going <= 0
        ? null
        : (going == 1 ? '1 идёт' : '$going идут');
    final friends = friendsGoingCount;
    final friendsPart = friends <= 0 ? null : _friendsRu(friends);
    if (goingPart == null && friendsPart == null) return '';
    if (goingPart != null && friendsPart != null) {
      return '$goingPart · $friendsPart';
    }
    return goingPart ?? friendsPart!;
  }

  static String _friendsRu(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return '$n друг';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$n друга';
    }
    return '$n друзей';
  }

  /// Null when the event has no photos - callers should render a local
  /// placeholder rather than hitting a network image widget at all (this
  /// used to fall back to a picsum.photos URL, which depends on a host
  /// that isn't reachable from every network).
  String? get coverPhoto => photos.isNotEmpty ? photos.first : null;

  Event copyWith({
    int? currentGuests,
    bool? isFavorite,
    EventStatus? status,
    String? chatId,
    DateTime? boostedUntil,
    bool? isBoosted,
    String? citySlug,
    List<FriendGoing>? friendsGoing,
    int? friendsGoingCount,
    int? viewCount,
    String? moderationNote,
    bool clearModerationNote = false,
    PlaceSummary? place,
    String? placeName,
  }) {
    return Event(
      id: id,
      host: host,
      format: format,
      title: title,
      description: description,
      photos: photos,
      tags: tags,
      startAt: startAt,
      endAt: endAt,
      address: address,
      location: location,
      minGuests: minGuests,
      maxGuests: maxGuests,
      currentGuests: currentGuests ?? this.currentGuests,
      priceType: priceType,
      priceAmount: priceAmount,
      requirements: requirements,
      pickupMethod: pickupMethod,
      pickupAddress: pickupAddress,
      portionWeightGrams: portionWeightGrams,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      chatId: chatId ?? this.chatId,
      boostedUntil: boostedUntil ?? this.boostedUntil,
      isBoosted: isBoosted ?? this.isBoosted,
      citySlug: citySlug ?? this.citySlug,
      friendsGoing: friendsGoing ?? this.friendsGoing,
      friendsGoingCount: friendsGoingCount ?? this.friendsGoingCount,
      viewCount: viewCount ?? this.viewCount,
      moderationNote: clearModerationNote
          ? null
          : (moderationNote ?? this.moderationNote),
      place: place ?? this.place,
      placeName: placeName ?? this.placeName,
    );
  }

  /// [fallbackHost] is used when the backend response doesn't include a
  /// nested `host` object - e.g. right after `POST /events`, whose response
  /// is the bare Prisma row (just `hostId`), not the `include: { host }`
  /// shape the list/detail endpoints return. Pass the user who's known to
  /// be the host (the current user, in that case) so the model doesn't have
  /// to fall back to a placeholder.
  factory Event.fromJson(Map<String, dynamic> json, {AppUser? fallbackHost}) {
    var host = json['host'] != null
        ? AppUser.fromJson(json['host'] as Map<String, dynamic>)
        : fallbackHost ??
            AppUser(
              id: json['hostId'] as String? ?? '',
              name: '',
              age: 0,
              city: '',
              memberSince: DateTime.now(),
            );
    final hostIsPro = json['hostIsOrganizerPro'] as bool?;
    if (hostIsPro == true && !host.hasActiveOrganizerPro) {
      host = host.copyWith(isOrganizerPro: true);
    }
    return Event(
        id: json['id'] as String,
        host: host,
        // Chat responses embed only a partial event summary
        // (id/title/photos/startAt/status) - default the rest so parsing
        // that shape doesn't throw.
        format: EventFormat.fromBackend(json['format'] as String? ?? 'IN_PERSON'),
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        photos: (json['photos'] as List?)?.cast<String>() ?? const [],
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        startAt: DateTime.parse(json['startAt'] as String),
        endAt: json['endAt'] != null
            ? DateTime.parse(json['endAt'] as String)
            : null,
        address: json['address'] as String? ?? '',
        location: GeoPoint(
          latitude: (json['lat'] as num?)?.toDouble() ?? 0,
          longitude: (json['lng'] as num?)?.toDouble() ?? 0,
        ),
        minGuests: json['minGuests'] as int? ?? 1,
        maxGuests: json['maxGuests'] as int? ?? 1,
        currentGuests: json['currentGuestsCount'] as int? ?? 0,
        priceType: PriceType.fromBackend(json['priceType'] as String? ?? 'FREE'),
        priceAmount: (json['priceAmount'] as num?)?.toDouble(),
        requirements: GuestRequirements.fromEventJson(json),
        pickupMethod: json['pickupMethod'] != null
            ? PickupMethod.fromBackend(json['pickupMethod'] as String)
            : null,
        pickupAddress: json['pickupAddress'] as String?,
        portionWeightGrams: json['portionWeightGrams'] as int?,
        status: EventStatus.fromBackend(json['status'] as String? ?? 'ACTIVE'),
        isFavorite: json['isFavorite'] as bool? ?? false,
        chatId: json['chatId'] as String?,
        boostedUntil: json['boostedUntil'] != null
            ? DateTime.parse(json['boostedUntil'] as String)
            : null,
        isBoosted: json['isBoosted'] as bool? ??
            (json['boostedUntil'] != null &&
                DateTime.parse(json['boostedUntil'] as String)
                    .isAfter(DateTime.now())),
        citySlug: json['citySlug'] as String? ?? 'minsk',
        friendsGoing: (json['friendsGoing'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(FriendGoing.fromJson)
                .toList() ??
            const [],
        friendsGoingCount: json['friendsGoingCount'] as int? ?? 0,
        viewCount: json['viewCount'] as int? ?? 0,
        moderationNote: json['moderationNote'] as String?,
        place: json['place'] is Map<String, dynamic>
            ? PlaceSummary.fromJson(json['place'] as Map<String, dynamic>)
            : null,
      );
  }

  /// Matches the backend's `CreateEventDto` / `UpdateEventDto` exactly -
  /// flat lat/lng and requirement* fields, no id/host/currentGuestsCount
  /// (the server owns those).
  Map<String, dynamic> toCreateJson() => {
        'format': format.backend,
        'title': title,
        'description': description,
        'photos': photos,
        'tags': tags,
        'startAt': startAt.toIso8601String(),
        if (endAt != null) 'endAt': endAt!.toIso8601String(),
        'address': address,
        'lat': location.latitude,
        'lng': location.longitude,
        'citySlug': citySlug,
        if (placeName != null && placeName!.isNotEmpty) 'placeName': placeName,
        'minGuests': minGuests,
        'maxGuests': maxGuests,
        'priceType': priceType.backend,
        if (priceAmount != null) 'priceAmount': priceAmount!.toInt(),
        ...requirements.toEventJson(),
        if (pickupMethod != null) 'pickupMethod': pickupMethod!.backend,
        if (pickupAddress != null) 'pickupAddress': pickupAddress,
        if (portionWeightGrams != null) 'portionWeightGrams': portionWeightGrams,
      };
}
