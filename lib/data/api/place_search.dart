import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/env.dart';
import '../models/event.dart';

class PlaceHit {
  const PlaceHit({
    required this.title,
    required this.subtitle,
    required this.point,
  });

  final String title;
  final String subtitle;
  final GeoPoint point;

  String get fullLabel {
    if (subtitle.isEmpty || subtitle == title) return title;
    return '$title, $subtitle';
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'lat': point.latitude,
        'lon': point.longitude,
      };

  factory PlaceHit.fromJson(Map<String, dynamic> json) => PlaceHit(
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        point: GeoPoint(
          latitude: (json['lat'] as num).toDouble(),
          longitude: (json['lon'] as num).toDouble(),
        ),
      );
}

/// Forward/reverse place lookup for the map picker.
///
/// Order: Yandex Geosuggest (orgs + addresses) → Yandex Geocoder →
/// Photon (OSM) → Nominatim.
class PlaceSearch {
  PlaceSearch({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'User-Agent': 'Pulse/1.0 (https://pulse-app.by; support@pulse-app.by)',
                },
              ),
            );

  final Dio _dio;
  static const _nominatim = 'https://nominatim.openstreetmap.org';
  static const _photon = 'https://photon.komoot.io/api/';
  static const _yandexGeocode = 'https://geocode-maps.yandex.ru/v1/';
  static const _yandexSuggest = 'https://suggest-maps.yandex.ru/v1/suggest';

  static String get _geocoderKey => Env.yandexGeocoderApiKey;
  static String get _suggestKey => Env.yandexGeosuggestApiKey;

  Future<List<PlaceHit>> search(
    String query, {
    GeoPoint? near,
    int limit = 8,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    if (_suggestKey.isNotEmpty) {
      try {
        final hits = await _searchGeosuggest(q, near: near, limit: limit);
        if (hits.isNotEmpty) return hits;
      } catch (e) {
        debugPrint('Yandex geosuggest skipped: $e');
      }
    }

    if (_geocoderKey.isNotEmpty) {
      try {
        final hits = await _searchYandex(q, near: near, limit: limit);
        if (hits.isNotEmpty) return hits;
      } catch (e) {
        debugPrint('Yandex geocode skipped: $e');
      }
    }

    try {
      final hits = await _searchPhoton(q, near: near, limit: limit);
      if (hits.isNotEmpty) return hits;
    } catch (e) {
      debugPrint('Photon geocode skipped: $e');
    }

    return _searchNominatim(q, near: near, limit: limit);
  }

  Future<PlaceHit?> reverse(GeoPoint point) async {
    if (_geocoderKey.isNotEmpty) {
      try {
        final hit = await _reverseYandex(point);
        if (hit != null) return hit;
      } catch (e) {
        debugPrint('Yandex reverse skipped: $e');
      }
    }
    try {
      final hit = await _reversePhoton(point);
      if (hit != null) return hit;
    } catch (_) {}
    return _reverseNominatim(point);
  }

  /// Suggest orgs (`biz`) + geo, then resolve each `uri` via Geocoder.
  Future<List<PlaceHit>> _searchGeosuggest(
    String query, {
    GeoPoint? near,
    required int limit,
  }) async {
    final params = <String, dynamic>{
      'apikey': _suggestKey,
      'text': query,
      'lang': 'ru',
      'results': limit.clamp(1, 10),
      'highlight': 0,
      'print_address': 1,
      'attrs': 'uri',
      // Organizations first (clubs, venues), plus addresses/streets.
      'types': 'biz,geo',
      'countries': 'by,ru',
    };
    final bias = near ?? const GeoPoint(latitude: 53.9023, longitude: 27.5619);
    params['ll'] = '${bias.longitude},${bias.latitude}';
    params['spn'] = '0.35,0.35';
    params['ull'] = '${bias.longitude},${bias.latitude}';

    final res = await _dio.get(_yandexSuggest, queryParameters: params);
    final results = res.data is Map ? res.data['results'] : null;
    if (results is! List || results.isEmpty) return const [];

    final suggestions = <({String title, String subtitle, String? uri})>[];
    for (final raw in results) {
      if (raw is! Map) continue;
      final titleNode = raw['title'];
      final title = titleNode is Map
          ? (titleNode['text'] as String? ?? '').trim()
          : '';
      if (title.isEmpty) continue;
      final subtitleNode = raw['subtitle'];
      var subtitle = subtitleNode is Map
          ? (subtitleNode['text'] as String? ?? '').trim()
          : '';
      final address = raw['address'];
      if (subtitle.isEmpty && address is Map) {
        subtitle = (address['formatted_address'] as String? ?? '').trim();
      }
      if (subtitle.startsWith('$title,')) {
        subtitle = subtitle.substring(title.length + 1).trim();
      } else if (subtitle == title) {
        subtitle = '';
      }
      final uri = (raw['uri'] as String?)?.trim();
      suggestions.add((title: title, subtitle: subtitle, uri: uri));
    }

    if (suggestions.isEmpty) return const [];

    final resolved = await Future.wait(
      suggestions.map((s) async {
        if (s.uri == null || s.uri!.isEmpty || _geocoderKey.isEmpty) {
          return null;
        }
        try {
          final point = await _geocodeUri(s.uri!);
          if (point == null) return null;
          return PlaceHit(
            title: s.title,
            subtitle: s.subtitle,
            point: point,
          );
        } catch (e) {
          debugPrint('Geosuggest uri resolve failed: $e');
          return null;
        }
      }),
    );

    return resolved.whereType<PlaceHit>().toList();
  }

  Future<GeoPoint?> _geocodeUri(String uri) async {
    final res = await _dio.get(
      _yandexGeocode,
      queryParameters: {
        'apikey': _geocoderKey,
        'uri': uri,
        'format': 'json',
        'lang': 'ru_RU',
        'results': 1,
      },
    );
    final hits = _parseYandex(res.data);
    return hits.isEmpty ? null : hits.first.point;
  }

  Future<List<PlaceHit>> _searchYandex(
    String query, {
    GeoPoint? near,
    required int limit,
  }) async {
    final params = <String, dynamic>{
      'apikey': _geocoderKey,
      'geocode': query,
      'format': 'json',
      'lang': 'ru_RU',
      'results': limit,
    };
    final bias = near ?? const GeoPoint(latitude: 53.9023, longitude: 27.5619);
    params['ll'] = '${bias.longitude},${bias.latitude}';
    params['spn'] = '0.35,0.35';
    params['rspn'] = 0;

    final res = await _dio.get(_yandexGeocode, queryParameters: params);
    return _parseYandex(res.data);
  }

  Future<PlaceHit?> _reverseYandex(GeoPoint point) async {
    final res = await _dio.get(
      _yandexGeocode,
      queryParameters: {
        'apikey': _geocoderKey,
        'geocode': '${point.longitude},${point.latitude}',
        'format': 'json',
        'lang': 'ru_RU',
        'results': 1,
      },
    );
    final hits = _parseYandex(res.data);
    return hits.isEmpty ? null : hits.first;
  }

  List<PlaceHit> _parseYandex(dynamic data) {
    if (data is! Map) return const [];
    final response = data['response'];
    if (response is! Map) return const [];
    final collection = response['GeoObjectCollection'];
    if (collection is! Map) return const [];
    final members = collection['featureMember'];
    if (members is! List) return const [];

    final hits = <PlaceHit>[];
    for (final raw in members) {
      if (raw is! Map) continue;
      final geo = raw['GeoObject'];
      if (geo is! Map) continue;
      final meta = geo['metaDataProperty'];
      final geocoderMeta = meta is Map ? meta['GeocoderMetaData'] : null;
      final text = geocoderMeta is Map ? (geocoderMeta['text'] as String? ?? '') : '';
      final name = (geo['name'] as String?)?.trim();
      final description = (geo['description'] as String?)?.trim() ?? '';
      final pointNode = geo['Point'];
      final pos = pointNode is Map ? pointNode['pos'] as String? : null;
      if (pos == null) continue;
      final parts = pos.split(' ');
      if (parts.length < 2) continue;
      final lon = double.tryParse(parts[0]);
      final lat = double.tryParse(parts[1]);
      if (lat == null || lon == null) continue;

      final title = (name != null && name.isNotEmpty)
          ? name
          : (text.split(',').first.trim().isNotEmpty
              ? text.split(',').first.trim()
              : 'Место на карте');
      var subtitle = description.isNotEmpty ? description : text;
      if (subtitle.startsWith('$title,')) {
        subtitle = subtitle.substring(title.length + 1).trim();
      } else if (subtitle == title) {
        subtitle = '';
      }

      hits.add(
        PlaceHit(
          title: title,
          subtitle: subtitle,
          point: GeoPoint(latitude: lat, longitude: lon),
        ),
      );
    }
    return hits;
  }

  Future<List<PlaceHit>> _searchPhoton(
    String query, {
    GeoPoint? near,
    required int limit,
  }) async {
    final params = <String, dynamic>{
      'q': query,
      'lang': 'ru',
      'limit': limit,
    };
    final bias = near ?? const GeoPoint(latitude: 53.9023, longitude: 27.5619);
    params['lat'] = bias.latitude;
    params['lon'] = bias.longitude;
    final res = await _dio.get(_photon, queryParameters: params);
    return _parsePhoton(res.data);
  }

  Future<PlaceHit?> _reversePhoton(GeoPoint point) async {
    final res = await _dio.get(
      'https://photon.komoot.io/reverse',
      queryParameters: {
        'lat': point.latitude,
        'lon': point.longitude,
        'lang': 'ru',
      },
    );
    final hits = _parsePhoton(res.data);
    return hits.isEmpty ? null : hits.first;
  }

  List<PlaceHit> _parsePhoton(dynamic data) {
    if (data is! Map) return const [];
    final features = data['features'];
    if (features is! List) return const [];
    final hits = <PlaceHit>[];
    for (final f in features) {
      if (f is! Map) continue;
      final props = f['properties'];
      final geom = f['geometry'];
      if (props is! Map || geom is! Map) continue;
      final coords = geom['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final name = (props['name'] as String?)?.trim();
      final street = [
        props['street'],
        props['housenumber'],
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
      final city = [
        props['district'],
        props['city'],
        props['state'],
        props['country'],
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
      final title = (name != null && name.isNotEmpty)
          ? name
          : (street.isNotEmpty ? street : 'Место на карте');
      final subtitleParts = <String>[
        if (name != null && name.isNotEmpty && street.isNotEmpty) street,
        if (city.isNotEmpty) city,
      ];
      hits.add(
        PlaceHit(
          title: title,
          subtitle: subtitleParts.join(' · '),
          point: GeoPoint(latitude: lat, longitude: lon),
        ),
      );
    }
    return hits;
  }

  Future<List<PlaceHit>> _searchNominatim(
    String query, {
    GeoPoint? near,
    required int limit,
  }) async {
    final params = <String, dynamic>{
      'q': query,
      'format': 'jsonv2',
      'addressdetails': 1,
      'limit': limit,
      'accept-language': 'ru',
      'countrycodes': 'by',
    };
    final bias = near ?? const GeoPoint(latitude: 53.9023, longitude: 27.5619);
    const d = 0.35;
    params['viewbox'] =
        '${bias.longitude - d},${bias.latitude + d},${bias.longitude + d},${bias.latitude - d}';
    params['bounded'] = 0;

    final res = await _dio.get('$_nominatim/search', queryParameters: params);
    final items = (res.data as List).cast<Map<String, dynamic>>();
    return items.map(_fromNominatim).toList();
  }

  Future<PlaceHit?> _reverseNominatim(GeoPoint point) async {
    final res = await _dio.get(
      '$_nominatim/reverse',
      queryParameters: {
        'lat': point.latitude,
        'lon': point.longitude,
        'format': 'jsonv2',
        'addressdetails': 1,
        'accept-language': 'ru',
        'zoom': 16,
      },
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;
    if (data['error'] != null) return null;
    return _fromNominatim({
      ...data,
      'lat': point.latitude.toString(),
      'lon': point.longitude.toString(),
    });
  }

  PlaceHit _fromNominatim(Map<String, dynamic> json) {
    final lat = double.parse(json['lat'].toString());
    final lon = double.parse(json['lon'].toString());
    final name = (json['name'] as String?)?.trim();
    final display = (json['display_name'] as String?)?.trim() ?? '';
    final title = (name != null && name.isNotEmpty)
        ? name
        : (display.split(',').first.trim().isNotEmpty
            ? display.split(',').first.trim()
            : 'Место на карте');
    var subtitle = display;
    if (subtitle.startsWith('$title,')) {
      subtitle = subtitle.substring(title.length + 1).trim();
    } else if (subtitle == title) {
      subtitle = '';
    }
    return PlaceHit(
      title: title,
      subtitle: subtitle,
      point: GeoPoint(latitude: lat, longitude: lon),
    );
  }
}
