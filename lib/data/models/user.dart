import 'enums.dart';
import 'social_networks.dart';


class UserActivity {
  final int attendedMeetings;
  final int hostedDinners;
  final int takeawayOrdersPrepared;
  final int noShowCount;
  final int attendanceMarkedTotal;
  /// 0-1 when server has enough samples; otherwise null.
  final double? noShowRatio;

  const UserActivity({
    this.attendedMeetings = 0,
    this.hostedDinners = 0,
    this.takeawayOrdersPrepared = 0,
    this.noShowCount = 0,
    this.attendanceMarkedTotal = 0,
    this.noShowRatio,
  });

  factory UserActivity.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserActivity();
    return UserActivity(
      attendedMeetings: json['attendedMeetings'] as int? ?? 0,
      hostedDinners: json['hostedDinners'] as int? ?? 0,
      takeawayOrdersPrepared: json['takeawayOrdersPrepared'] as int? ?? 0,
      noShowCount: json['noShowCount'] as int? ?? 0,
      attendanceMarkedTotal: json['attendanceMarkedTotal'] as int? ?? 0,
      noShowRatio: (json['noShowRatio'] as num?)?.toDouble(),
    );
  }

  bool get hasNoShowSignal => noShowCount > 0 && noShowRatio != null;

  String get noShowLabel {
    final total = attendanceMarkedTotal > 0
        ? attendanceMarkedTotal
        : (attendedMeetings + noShowCount);
    if (total <= 0 || noShowRatio == null) return '';
    final pct = (noShowRatio! * 100).round();
    return 'Неявки $noShowCount из $total ($pct%)';
  }
}


class AuthorPathNext {
  final int level;
  final String title;
  final String hint;
  final double progress;

  const AuthorPathNext({
    required this.level,
    required this.title,
    required this.hint,
    required this.progress,
  });

  factory AuthorPathNext.fromJson(Map<String, dynamic> json) => AuthorPathNext(
        level: json['level'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        hint: json['hint'] as String? ?? '',
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
      );
}

class AuthorPath {
  final int level;
  final String title;
  final int eventsHosted;
  final int guestsHosted;
  final int hostReviewsCount;
  final double hostRating;
  final bool hasCriterionBadge;
  final AuthorPathNext? next;

  const AuthorPath({
    this.level = 0,
    this.title = 'Новичок',
    this.eventsHosted = 0,
    this.guestsHosted = 0,
    this.hostReviewsCount = 0,
    this.hostRating = 100,
    this.hasCriterionBadge = false,
    this.next,
  });

  factory AuthorPath.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AuthorPath();
    final nextJson = json['next'];
    return AuthorPath(
      level: json['level'] as int? ?? 0,
      title: json['title'] as String? ?? 'Новичок',
      eventsHosted: json['eventsHosted'] as int? ?? 0,
      guestsHosted: json['guestsHosted'] as int? ?? 0,
      hostReviewsCount: json['hostReviewsCount'] as int? ?? 0,
      hostRating: (json['hostRating'] as num?)?.toDouble() ?? 100,
      hasCriterionBadge: json['hasCriterionBadge'] as bool? ?? false,
      next: nextJson is Map<String, dynamic>
          ? AuthorPathNext.fromJson(nextJson)
          : null,
    );
  }
}

class AuthorOfMonthShowcase {
  final String period;
  final String periodLabel;
  final String? note;
  final AppUser? author;

  const AuthorOfMonthShowcase({
    required this.period,
    this.periodLabel = '',
    this.note,
    this.author,
  });

  factory AuthorOfMonthShowcase.fromJson(Map<String, dynamic> json) {
    final authorJson = json['author'];
    return AuthorOfMonthShowcase(
      period: json['period'] as String? ?? '',
      periodLabel: json['periodLabel'] as String? ?? '',
      note: json['note'] as String?,
      author: authorJson is Map<String, dynamic> ? AppUser.fromJson(authorJson) : null,
    );
  }
}

class AppUser {
  final String id;
  final String name;
  final int age;
  final String city;
  final String? avatarUrl;
  final String? bio;
  final String? whatICook;
  final Map<String, String> socialLinks;
  final List<String> photos;
  final double rating; // display cache (host-first)
  final double hostRating;
  final int hostReviewsCount;
  final double guestRating;
  final int guestReviewsCount;
  final int eventsCount;
  final int reviewsCount;
  final int followersCount;
  final int followingCount;
  final DateTime memberSince;
  final List<Badge> badges;
  final bool isAdmin;
  final bool isBlocked;
  final UserRole role;
  /// Whether the current viewer follows this user (from public profile).
  final bool isFollowing;
  /// Whether the current viewer has blocked this user (from public profile).
  final bool isBlockedByMe;
  final UserActivity activity;
  final AuthorPath authorPath;
  /// Cached host author-path level 0-6 (feed talents).
  final int authorLevel;
  /// YYYY-MM if this user is the current author of the month.
  final String? authorOfMonthPeriod;
  /// Curated special-project / collab invite.
  final bool specialProject;
  /// Paid Organizer Pro end date (null if never subscribed).
  final DateTime? organizerProUntil;
  final bool isOrganizerPro;

  bool get canHostEvents => role.canHostEvents || isAdmin;

  bool get hasActiveOrganizerPro {
    if (isOrganizerPro) return true;
    final until = organizerProUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  const AppUser({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    this.avatarUrl,
    this.bio,
    this.whatICook,
    this.socialLinks = const {},
    this.photos = const [],
    this.rating = 0,
    this.hostRating = 0,
    this.hostReviewsCount = 0,
    this.guestRating = 0,
    this.guestReviewsCount = 0,
    this.eventsCount = 0,
    this.reviewsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    required this.memberSince,
    this.badges = const [],
    this.isAdmin = false,
    this.isBlocked = false,
    this.role = UserRole.user,
    this.isFollowing = false,
    this.isBlockedByMe = false,
    this.activity = const UserActivity(),
    this.authorPath = const AuthorPath(),
    this.authorLevel = 0,
    this.authorOfMonthPeriod,
    this.specialProject = false,
    this.organizerProUntil,
    this.isOrganizerPro = false,
  });

  /// Rating shown for a host on event cards / host profile.
  bool get isTalentAuthor => authorLevel >= 5 || authorPath.level >= 5;

  bool get isAuthorOfMonth {
    if (authorOfMonthPeriod == null || authorOfMonthPeriod!.isEmpty) return false;
    final now = DateTime.now().toUtc();
    final key = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    return authorOfMonthPeriod == key;
  }

  double get displayHostRating => hostReviewsCount > 0 ? hostRating : rating;

  int get displayHostReviewsCount => hostReviewsCount;

  String get memberSinceLabel {
    final years = DateTime.now().difference(memberSince).inDays ~/ 365;
    if (years <= 0) {
      final months = DateTime.now().difference(memberSince).inDays ~/ 30;
      if (months <= 0) return 'Новичок';
      return '$months мес.';
    }
    if (years == 1) return '1 год';
    if (years >= 2 && years <= 4) return '$years года';
    return '$years лет';
  }

  static Map<String, String> _parseSocialLinks(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    for (final key in SocialNetworks.keys) {
      final value = raw[key];
      if (value is String && value.trim().isNotEmpty) {
        out[key] = value.trim();
      }
    }
    return out;
  }

  /// The backend leaves name/age/city null until the user fills in their
  /// profile (screen 10), so this falls back to sensible placeholders rather
  /// than a non-nullable-cast crash right after first login.
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Новый пользователь',
        age: json['age'] as int? ?? 0,
        city: json['city'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
        bio: json['bio'] as String?,
        whatICook: json['whatICook'] as String?,
        socialLinks: _parseSocialLinks(json['socialLinks']),
        photos: (json['photos'] as List?)?.cast<String>() ?? const [],
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        hostRating: (json['hostRating'] as num?)?.toDouble() ??
            (json['rating'] as num?)?.toDouble() ??
            0,
        hostReviewsCount: json['hostReviewsCount'] as int? ?? 0,
        guestRating: (json['guestRating'] as num?)?.toDouble() ?? 0,
        guestReviewsCount: json['guestReviewsCount'] as int? ?? 0,
        eventsCount: json['eventsCount'] as int? ?? 0,
        reviewsCount: json['reviewsCount'] as int? ?? 0,
        followersCount: json['followersCount'] as int? ?? 0,
        followingCount: json['followingCount'] as int? ?? 0,
        // Host summaries embedded in events/applications/etc. are a select()
        // subset (id/name/avatarUrl/rating/city only) - memberSince is
        // frequently absent there, so this can't be a hard parse.
        memberSince: json['memberSince'] != null
            ? DateTime.parse(json['memberSince'] as String)
            : DateTime.now(),
        // The backend returns the UserBadge join row ({badge: {...}, earnedAt,
        // ...}), not the Badge itself - unwrap it if present.
        badges: (json['badges'] as List?)
                ?.map((e) => Badge.fromJson(
                    ((e as Map<String, dynamic>)['badge'] as Map<String, dynamic>?) ?? e))
                .toList() ??
            const [],
        isAdmin: json['isAdmin'] as bool? ?? false,
        isBlocked: json['isBlocked'] as bool? ?? false,
        role: UserRole.fromBackend(json['role'] as String?),
        isFollowing: json['isFollowing'] as bool? ?? false,
        isBlockedByMe: json['isBlockedByMe'] as bool? ?? false,
        activity: UserActivity.fromJson(json['activity'] as Map<String, dynamic>?),
        authorPath: AuthorPath.fromJson(json['authorPath'] as Map<String, dynamic>?),
        authorLevel: json['authorLevel'] as int? ??
            (json['authorPath'] is Map
                ? (json['authorPath'] as Map)['level'] as int? ?? 0
                : 0),
        authorOfMonthPeriod: json['authorOfMonthPeriod'] as String?,
        specialProject: json['specialProject'] as bool? ?? false,
        organizerProUntil: json['organizerProUntil'] != null
            ? DateTime.parse(json['organizerProUntil'] as String)
            : null,
        isOrganizerPro: json['isOrganizerPro'] as bool? ??
            (json['organizerProUntil'] != null &&
                DateTime.parse(json['organizerProUntil'] as String)
                    .isAfter(DateTime.now())),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'city': city,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'whatICook': whatICook,
        'socialLinks': socialLinks,
        'photos': photos,
        'rating': rating,
        'eventsCount': eventsCount,
        'reviewsCount': reviewsCount,
        'followersCount': followersCount,
        'followingCount': followingCount,
        'memberSince': memberSince.toIso8601String(),
        'badges': badges.map((e) => e.toJson()).toList(),
        'isAdmin': isAdmin,
        'isBlocked': isBlocked,
        'role': role.backend,
      };

  AppUser copyWith({
    String? name,
    int? age,
    String? city,
    String? avatarUrl,
    String? bio,
    String? whatICook,
    Map<String, String>? socialLinks,
    List<String>? photos,
    double? rating,
    double? hostRating,
    int? hostReviewsCount,
    double? guestRating,
    int? guestReviewsCount,
    int? eventsCount,
    int? reviewsCount,
    int? followersCount,
    int? followingCount,
    bool? isBlocked,
    bool? isFollowing,
    bool? isBlockedByMe,
    UserActivity? activity,
    AuthorPath? authorPath,
    int? authorLevel,
    String? authorOfMonthPeriod,
    bool clearAuthorOfMonthPeriod = false,
    bool? specialProject,
    UserRole? role,
    bool? isAdmin,
    DateTime? organizerProUntil,
    bool clearOrganizerProUntil = false,
    bool? isOrganizerPro,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      city: city ?? this.city,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      whatICook: whatICook ?? this.whatICook,
      socialLinks: socialLinks ?? this.socialLinks,
      photos: photos ?? this.photos,
      rating: rating ?? this.rating,
      hostRating: hostRating ?? this.hostRating,
      hostReviewsCount: hostReviewsCount ?? this.hostReviewsCount,
      guestRating: guestRating ?? this.guestRating,
      guestReviewsCount: guestReviewsCount ?? this.guestReviewsCount,
      eventsCount: eventsCount ?? this.eventsCount,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      memberSince: memberSince,
      badges: badges,
      isAdmin: isAdmin ?? this.isAdmin,
      isBlocked: isBlocked ?? this.isBlocked,
      role: role ?? this.role,
      isFollowing: isFollowing ?? this.isFollowing,
      isBlockedByMe: isBlockedByMe ?? this.isBlockedByMe,
      activity: activity ?? this.activity,
      authorPath: authorPath ?? this.authorPath,
      authorLevel: authorLevel ?? this.authorLevel,
      authorOfMonthPeriod: clearAuthorOfMonthPeriod
          ? null
          : (authorOfMonthPeriod ?? this.authorOfMonthPeriod),
      specialProject: specialProject ?? this.specialProject,
      organizerProUntil: clearOrganizerProUntil
          ? null
          : (organizerProUntil ?? this.organizerProUntil),
      isOrganizerPro: isOrganizerPro ?? this.isOrganizerPro,
    );
  }
}

class Badge {
  final String code;
  final String title;
  final String description;
  final String icon; // emoji or material icon name

  const Badge({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
  });

  factory Badge.fromJson(Map<String, dynamic> json) => Badge(
        code: json['code'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? json['iconUrl'] as String? ?? '🏅',
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'description': description,
        'icon': icon,
      };
}
