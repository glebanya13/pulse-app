import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'place_search.dart';

/// Recent map place picks, stored on-device.
abstract final class PlaceSearchHistory {
  static const _key = 'map_place_search_history_v1';
  static const _maxItems = 12;

  static Future<List<PlaceHit>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final hits = <PlaceHit>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item);
        if (map is Map<String, dynamic>) {
          hits.add(PlaceHit.fromJson(map));
        } else if (map is Map) {
          hits.add(PlaceHit.fromJson(Map<String, dynamic>.from(map)));
        }
      } catch (_) {}
    }
    return hits;
  }

  static Future<void> add(PlaceHit place) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await load();
    final next = <PlaceHit>[
      place,
      ...existing.where(
        (p) =>
            p.title != place.title ||
            (p.point.latitude - place.point.latitude).abs() > 0.0001 ||
            (p.point.longitude - place.point.longitude).abs() > 0.0001,
      ),
    ].take(_maxItems).toList();
    await prefs.setStringList(
      _key,
      next.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
