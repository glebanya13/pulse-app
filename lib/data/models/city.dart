import '../models/event.dart';

class AppCity {
  const AppCity({
    required this.slug,
    required this.name,
    required this.country,
    required this.currency,
    required this.lat,
    required this.lng,
  });

  final String slug;
  final String name;
  /// BY | RU
  final String country;
  /// BYN | RUB
  final String currency;
  final double lat;
  final double lng;

  GeoPoint get center => GeoPoint(latitude: lat, longitude: lng);

  bool get isBelarus => country == 'BY';
  bool get isRussia => country == 'RU';

  factory AppCity.fromJson(Map<String, dynamic> json) => AppCity(
        slug: json['slug'] as String,
        name: json['name'] as String,
        country: json['country'] as String? ?? 'BY',
        currency: json['currency'] as String? ?? 'BYN',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  /// Soft bbox around city center (~40km) for map GPS snap.
  bool containsApprox(double latitude, double longitude) {
    const delta = 0.45;
    return latitude >= lat - delta &&
        latitude <= lat + delta &&
        longitude >= lng - delta &&
        longitude <= lng + delta;
  }
}

/// Offline fallback until /cities loads.
const AppCity kDefaultCity = AppCity(
  slug: 'minsk',
  name: 'Минск',
  country: 'BY',
  currency: 'BYN',
  lat: 53.9023,
  lng: 27.5619,
);
