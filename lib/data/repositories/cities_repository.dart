import '../api/api_client.dart';
import '../models/city.dart';

class CitiesRepository {
  CitiesRepository(this._api);

  final ApiClient _api;
  List<AppCity>? _cache;

  Future<List<AppCity>> list({bool force = false}) async {
    if (!force && _cache != null) return _cache!;
    try {
      final res = await _api.dio.get('/cities');
      final raw = res.data;
      final list = (raw is List ? raw : <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map(AppCity.fromJson)
          .toList();
      if (list.isNotEmpty) {
        _cache = list;
        return list;
      }
    } catch (_) {
      // Fall through to defaults.
    }
    return _cache ?? const [kDefaultCity];
  }

  AppCity? bySlug(String slug, List<AppCity> cities) {
    for (final c in cities) {
      if (c.slug == slug) return c;
    }
    return null;
  }
}
