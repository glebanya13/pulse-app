import 'enums.dart';
import 'user.dart';

/// One verbal choice that maps to a 0-100 score.
class ReviewLevel {
  const ReviewLevel({required this.label, required this.score});

  final String label;
  final int score;
}

/// Standard ladder - 100 is "best experience of my life", not a habit.
const List<ReviewLevel> kDefaultReviewLevels = [
  ReviewLevel(label: 'Нормально', score: 50),
  ReviewLevel(label: 'Хорошо', score: 70),
  ReviewLevel(label: 'Очень хорошо', score: 85),
  ReviewLevel(label: 'Почти идеально', score: 95),
  ReviewLevel(label: 'Вау', score: 100),
];

class ReviewCriterion {
  const ReviewCriterion({
    required this.backendKey,
    required this.label,
    required this.question,
    required this.weight,
    this.levels = kDefaultReviewLevels,
  });

  final String backendKey;
  final String label;
  final String question;
  /// Relative weight for HOST overall (ignored for guest equal-average).
  final double weight;
  final List<ReviewLevel> levels;
}

/// Host portrait criteria - weights sum to 1.0 (must match backend rating-score.ts).
const List<ReviewCriterion> hostReviewCriteria = [
  ReviewCriterion(
    backendKey: 'taste',
    label: 'Вкус',
    question: 'Как вам вкус еды?',
    weight: 0.25,
    levels: [
      ReviewLevel(label: 'Нормально', score: 50),
      ReviewLevel(label: 'Вкусно', score: 70),
      ReviewLevel(label: 'Очень вкусно', score: 85),
      ReviewLevel(label: 'Почти идеально', score: 95),
      ReviewLevel(label: 'Вау', score: 100),
    ],
  ),
  ReviewCriterion(
    backendKey: 'atmosphere',
    label: 'Атмосфера',
    question: 'Какая была атмосфера?',
    weight: 0.18,
  ),
  ReviewCriterion(
    backendKey: 'hospitality',
    label: 'Гостеприимство',
    question: 'Насколько гостеприимно вас приняли?',
    weight: 0.2,
  ),
  ReviewCriterion(
    backendKey: 'sociability',
    label: 'Общительность',
    question: 'Легко ли было общаться?',
    weight: 0.08,
  ),
  ReviewCriterion(
    backendKey: 'organization',
    label: 'Организация',
    question: 'Насколько всё было организовано?',
    weight: 0.1,
  ),
  ReviewCriterion(
    backendKey: 'cleanliness',
    label: 'Чистота',
    question: 'Как с чистотой и порядком?',
    weight: 0.1,
  ),
  ReviewCriterion(
    backendKey: 'matchesDescription',
    label: 'Соответствие ожиданиям',
    question: 'Совпало ли с описанием?',
    weight: 0.04,
  ),
  ReviewCriterion(
    backendKey: 'vibe',
    label: 'Вайб / уникальность',
    question: 'Был ли «вау» и запомнившаяся фишка?',
    weight: 0.05,
    levels: [
      ReviewLevel(label: 'Обычный вечер', score: 50),
      ReviewLevel(label: 'Приятно', score: 70),
      ReviewLevel(label: 'Запомнилось', score: 85),
      ReviewLevel(label: 'Почти идеально', score: 95),
      ReviewLevel(label: 'Вау', score: 100),
    ],
  ),
];

const List<ReviewCriterion> guestReviewCriteria = [
  ReviewCriterion(
    backendKey: 'punctuality',
    label: 'Пунктуальность',
    question: 'Пришёл вовремя?',
    weight: 1,
    levels: [
      ReviewLevel(label: 'Опоздал', score: 50),
      ReviewLevel(label: 'Почти вовремя', score: 70),
      ReviewLevel(label: 'Вовремя', score: 85),
      ReviewLevel(label: 'Почти идеально', score: 95),
      ReviewLevel(label: 'Идеально', score: 100),
    ],
  ),
  ReviewCriterion(
    backendKey: 'politeness',
    label: 'Вежливость',
    question: 'Как с уважением и тоном?',
    weight: 1,
    levels: [
      ReviewLevel(label: 'Нормально', score: 50),
      ReviewLevel(label: 'Вежливо', score: 70),
      ReviewLevel(label: 'Очень тактично', score: 85),
      ReviewLevel(label: 'Почти идеально', score: 95),
      ReviewLevel(label: 'Образцово', score: 100),
    ],
  ),
  ReviewCriterion(
    backendKey: 'communicability',
    label: 'Коммуникабельность',
    question: 'Легко ли было общаться?',
    weight: 1,
    levels: [
      ReviewLevel(label: 'Сдержанно', score: 50),
      ReviewLevel(label: 'Нормально', score: 70),
      ReviewLevel(label: 'Легко', score: 85),
      ReviewLevel(label: 'Очень легко', score: 95),
      ReviewLevel(label: 'Душа компании', score: 100),
    ],
  ),
  ReviewCriterion(
    backendKey: 'ruleFollowing',
    label: 'Соблюдение правил',
    question: 'Соблюдал ли договорённости дома?',
    weight: 1,
    levels: [
      ReviewLevel(label: 'С оговорками', score: 50),
      ReviewLevel(label: 'В целом да', score: 70),
      ReviewLevel(label: 'Да', score: 85),
      ReviewLevel(label: 'Почти идеально', score: 95),
      ReviewLevel(label: 'Безупречно', score: 100),
    ],
  ),
  ReviewCriterion(
    backendKey: 'tidiness',
    label: 'Аккуратность',
    question: 'Как с аккуратностью за столом и в доме?',
    weight: 1,
    levels: [
      ReviewLevel(label: 'Нормально', score: 50),
      ReviewLevel(label: 'Аккуратно', score: 70),
      ReviewLevel(label: 'Очень аккуратно', score: 85),
      ReviewLevel(label: 'Почти идеально', score: 95),
      ReviewLevel(label: 'Идеально', score: 100),
    ],
  ),
  ReviewCriterion(
    backendKey: 'overallImpression',
    label: 'Общее впечатление',
    question: 'Хотели бы снова пригласить?',
    weight: 1,
    levels: [
      ReviewLevel(label: 'Скорее нет', score: 50),
      ReviewLevel(label: 'Можно', score: 70),
      ReviewLevel(label: 'Да', score: 85),
      ReviewLevel(label: 'Очень хочется', score: 95),
      ReviewLevel(label: 'Обязательно', score: 100),
    ],
  ),
];

List<ReviewCriterion> criteriaFor(ReviewTargetRole role) =>
    role == ReviewTargetRole.host ? hostReviewCriteria : guestReviewCriteria;

/// Russian labels kept for backwards-compatible score maps in UI/history.
const List<String> hostReviewCategories = [
  'Вкус',
  'Атмосфера',
  'Гостеприимство',
  'Общительность',
  'Организация',
  'Чистота',
  'Соответствие ожиданиям',
  'Вайб / уникальность',
];

const List<String> guestReviewCategories = [
  'Пунктуальность',
  'Вежливость',
  'Коммуникабельность',
  'Соблюдение правил',
  'Аккуратность',
  'Общее впечатление',
];

const Map<String, String> reviewCategoryBackendKeys = {
  'Вкус': 'taste',
  'Атмосфера': 'atmosphere',
  'Гостеприимство': 'hospitality',
  'Чистота': 'cleanliness',
  'Общительность': 'sociability',
  'Соответствие описанию': 'matchesDescription',
  'Соответствие ожиданиям': 'matchesDescription',
  'Организация': 'organization',
  'Вайб': 'vibe',
  'Вайб / уникальность': 'vibe',
  'Пунктуальность': 'punctuality',
  'Вежливость': 'politeness',
  'Коммуникабельность': 'communicability',
  'Соблюдение правил': 'ruleFollowing',
  'Аккуратность': 'tidiness',
  'Общее впечатление': 'overallImpression',
};

const Map<String, String> reviewCategoryLabelsByBackendKey = {
  'taste': 'Вкус',
  'atmosphere': 'Атмосфера',
  'hospitality': 'Гостеприимство',
  'cleanliness': 'Чистота',
  'sociability': 'Общительность',
  'matchesDescription': 'Соответствие ожиданиям',
  'organization': 'Организация',
  'vibe': 'Вайб / уникальность',
  'punctuality': 'Пунктуальность',
  'politeness': 'Вежливость',
  'communicability': 'Коммуникабельность',
  'ruleFollowing': 'Соблюдение правил',
  'tidiness': 'Аккуратность',
  'overallImpression': 'Общее впечатление',
};

/// Weighted overall for host; equal average for guest. Matches backend.
double computeReviewOverall(Map<String, int> scoresByBackendKey, ReviewTargetRole role) {
  if (scoresByBackendKey.isEmpty) return 0;
  if (role == ReviewTargetRole.host) {
    var weighted = 0.0;
    var weightTotal = 0.0;
    for (final c in hostReviewCriteria) {
      final v = scoresByBackendKey[c.backendKey];
      if (v == null) continue;
      weighted += v * c.weight;
      weightTotal += c.weight;
    }
    if (weightTotal > 0) return weighted / weightTotal;
  }
  final values = scoresByBackendKey.values;
  return values.reduce((a, b) => a + b) / values.length;
}

/// Average per host criterion label across reviews (for profile portrait).
Map<String, int> averageHostCriteria(List<Review> reviews) {
  final hostReviews = reviews.where((r) => r.targetRole == ReviewTargetRole.host);
  final sums = <String, double>{};
  final counts = <String, int>{};
  for (final r in hostReviews) {
    for (final e in r.scores.entries) {
      sums[e.key] = (sums[e.key] ?? 0) + e.value;
      counts[e.key] = (counts[e.key] ?? 0) + 1;
    }
  }
  final out = <String, int>{};
  for (final key in hostReviewCategories) {
    final n = counts[key];
    if (n == null || n == 0) continue;
    out[key] = (sums[key]! / n).round();
  }
  return out;
}

class Review {
  final String id;
  final String eventId;
  final String eventTitle;
  final AppUser reviewer;
  final AppUser target;
  final ReviewTargetRole targetRole;
  /// Russian category label -> 0-100 (legacy UI map).
  final Map<String, int> scores;
  final String? comment;
  final DateTime createdAt;
  /// Server-computed overall when present.
  final int? serverOverallScore;

  const Review({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.reviewer,
    required this.target,
    required this.targetRole,
    required this.scores,
    this.comment,
    required this.createdAt,
    this.serverOverallScore,
  });

  Map<String, int> get scoresByBackendKey => {
        for (final e in scores.entries)
          if (reviewCategoryBackendKeys[e.key] != null)
            reviewCategoryBackendKeys[e.key]!: e.value,
      };

  double get overallScore {
    if (serverOverallScore != null) return serverOverallScore!.toDouble();
    return computeReviewOverall(scoresByBackendKey, targetRole);
  }

  List<String> get categories =>
      targetRole == ReviewTargetRole.host ? hostReviewCategories : guestReviewCategories;

  /// Matches the backend's `CreateReviewDto` exactly.
  Map<String, dynamic> toCreateJson() => {
        'targetId': target.id,
        'targetRole': targetRole.backend,
        'scores': {
          for (final entry in scores.entries)
            if (reviewCategoryBackendKeys[entry.key] != null)
              reviewCategoryBackendKeys[entry.key]!: entry.value,
        },
        if (comment != null) 'comment': comment,
      };

  factory Review.fromJson(
    Map<String, dynamic> json, {
    String? fallbackEventTitle,
    AppUser? fallbackTarget,
  }) {
    final backendScores = (json['scores'] as Map<String, dynamic>? ?? {});
    final russianScores = <String, int>{
      for (final entry in backendScores.entries)
        if (reviewCategoryLabelsByBackendKey[entry.key] != null)
          reviewCategoryLabelsByBackendKey[entry.key]!: (entry.value as num).toInt(),
    };
    final reviewerJson = json['reviewer'] as Map<String, dynamic>?;
    final eventJson = json['event'] as Map<String, dynamic>?;
    return Review(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      eventTitle: (eventJson?['title'] as String?) ?? fallbackEventTitle ?? '',
      reviewer: reviewerJson != null
          ? AppUser.fromJson(reviewerJson)
          : AppUser(
              id: json['reviewerId'] as String? ?? '',
              name: '',
              age: 0,
              city: '',
              memberSince: DateTime.now(),
            ),
      target: fallbackTarget ??
          AppUser(
            id: json['targetId'] as String? ?? '',
            name: '',
            age: 0,
            city: '',
            memberSince: DateTime.now(),
          ),
      targetRole: ReviewTargetRole.fromBackend(json['targetRole'] as String),
      scores: russianScores,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      serverOverallScore: (json['overallScore'] as num?)?.toInt(),
    );
  }
}
