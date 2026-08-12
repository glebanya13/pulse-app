import 'package:intl/intl.dart';

import '../../data/models/user.dart';

final _timeFormat = DateFormat('HH:mm', 'ru');
final _dayMonthFormat = DateFormat('d MMMM', 'ru');

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Сегодня в 19:00" / "Завтра в 12:00" / "18 мая в 15:00".
String formatEventDateTime(DateTime dt) {
  final now = DateTime.now();
  final tomorrow = now.add(const Duration(days: 1));
  final time = _timeFormat.format(dt);
  if (_isSameDay(dt, now)) return 'Сегодня в $time';
  if (_isSameDay(dt, tomorrow)) return 'Завтра в $time';
  return '${_dayMonthFormat.format(dt)} в $time';
}

String _dayWord(DateTime dt) {
  final now = DateTime.now();
  final tomorrow = now.add(const Duration(days: 1));
  if (_isSameDay(dt, now)) return 'Сегодня';
  if (_isSameDay(dt, tomorrow)) return 'Завтра';
  return _dayMonthFormat.format(dt);
}

/// Waiting window: "Сегодня, 16:00-21:00" / "12-14 июля" / single-point fallback.
String formatEventWindow(DateTime start, [DateTime? end]) {
  if (end == null || end.isAtSameMomentAs(start)) {
    return formatEventDateTime(start);
  }
  if (_isSameDay(start, end)) {
    return '${_dayWord(start)}, ${_timeFormat.format(start)}-${_timeFormat.format(end)}';
  }
  final sameMonth = start.year == end.year && start.month == end.month;
  if (sameMonth && start.hour == 0 && start.minute == 0 && end.hour == 0 && end.minute == 0) {
    return '${start.day}-${end.day} ${_dayMonthFormat.format(start).split(' ').last}';
  }
  return '${formatEventDateTime(start)} - ${formatEventDateTime(end)}';
}

/// "Сегодня" / "Вчера" / "3 июля" - used as day-group headers.
String formatDayLabel(DateTime dt) {
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(dt, now)) return 'Сегодня';
  if (_isSameDay(dt, yesterday)) return 'Вчера';
  return _dayMonthFormat.format(dt);
}

String formatTime(DateTime dt) => _timeFormat.format(dt);

String formatPrice(num? amount, {String currency = 'BYN'}) {
  if (amount == null) return '0 $currency';
  final formatted = NumberFormat.decimalPattern('ru').format(amount);
  return '$formatted $currency';
}

/// "Анна, 28 лет" or just "Анна" when age is missing / not set.
String formatUserName(String name, int age) {
  if (age <= 0) return name;
  return '$name, $age ${_ageWord(age)}';
}

String _ageWord(int age) {
  final n = age % 100;
  if (n >= 11 && n <= 14) return 'лет';
  return switch (n % 10) {
    1 => 'год',
    2 || 3 || 4 => 'года',
    _ => 'лет',
  };
}

/// Russian plural: 1 отзыв / 2 отзыва / 5 отзывов.
String russianPlural(int count, String one, String few, String many) {
  final n = count.abs() % 100;
  final n1 = n % 10;
  if (n > 10 && n < 20) return many;
  if (n1 > 1 && n1 < 5) return few;
  if (n1 == 1) return one;
  return many;
}

String reviewsLabel(int count) => russianPlural(count, 'отзыв', 'отзыва', 'отзывов');

String followersLabel(int count) =>
    russianPlural(count, 'подписчик', 'подписчика', 'подписчиков');

String meetingsLabel(int count) =>
    russianPlural(count, 'встреча', 'встречи', 'встреч');

String dinnersLabel(int count) =>
    russianPlural(count, 'домашний ужин', 'домашних ужина', 'домашних ужинов');

String ordersLabel(int count) =>
    russianPlural(count, 'заказ', 'заказа', 'заказов');

/// Headline + fact line for a review author (Telegram-style social proof).
({String headline, String? fact}) reviewAuthorFacts(AppUser reviewer) {
  final a = reviewer.activity;
  final name = reviewer.name.isEmpty ? 'Гость' : reviewer.name;

  if (a.takeawayOrdersPrepared > 0 &&
      a.takeawayOrdersPrepared >= a.hostedDinners) {
    return (
      headline: '$name · Домашний повар',
      fact: '${a.takeawayOrdersPrepared} ${ordersLabel(a.takeawayOrdersPrepared)}',
    );
  }
  if (a.hostedDinners > 0) {
    return (
      headline: '$name · Организатор',
      fact: '${a.hostedDinners} ${dinnersLabel(a.hostedDinners)}',
    );
  }

  final parts = <String>[name];
  if (reviewer.age > 0) parts.add('${reviewer.age} ${_ageWord(reviewer.age)}');
  final headline = parts.join(', ');
  final withCity = reviewer.city.trim().isEmpty
      ? headline
      : '$headline · ${reviewer.city.trim()}';

  if (a.attendedMeetings > 0) {
    return (
      headline: withCity,
      fact: '${a.attendedMeetings} ${meetingsLabel(a.attendedMeetings)}',
    );
  }
  return (headline: withCity, fact: null);
}

