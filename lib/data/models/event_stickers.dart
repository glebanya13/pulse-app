/// Nightlife stickers / tags used in create + filters.
///
/// Stored in [Event.tags] alongside free-form labels.
class EventStickers {
  EventStickers._();

  static const alcohol = 'Алкоголь';
  static const noAlcohol = 'Не алкоголь';
  static const eighteenPlus = '18+';
  static const live = 'Live';

  static const all = [alcohol, noAlcohol, eighteenPlus, live];

  /// Alcohol and non-alcohol are mutually exclusive.
  static bool isAlcoholPair(String tag) => tag == alcohol || tag == noAlcohol;

  /// Stickers first (in [all] order), then any other tags.
  static List<String> ordered(List<String> tags) {
    final stickers = all.where(tags.contains);
    final rest = tags.where((t) => !all.contains(t));
    return [...stickers, ...rest];
  }

  /// Toggle [tag] in [selected], enforcing alcohol XOR non-alcohol.
  static Set<String> toggle(Set<String> selected, String tag) {
    final next = Set<String>.of(selected);
    if (next.contains(tag)) {
      next.remove(tag);
      return next;
    }
    if (isAlcoholPair(tag)) {
      next.remove(alcohol);
      next.remove(noAlcohol);
    }
    next.add(tag);
    return next;
  }
}
