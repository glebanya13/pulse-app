import '../../data/models/event.dart';
import '../../data/models/city.dart';

/// Default city for map camera and place search bias (legacy alias).
@Deprecated('Use selectedCityProvider / AppCity instead')
abstract final class Minsk {
  static const double latitude = kDefaultCity.lat;
  static const double longitude = kDefaultCity.lng;

  static const GeoPoint center = GeoPoint(
    latitude: latitude,
    longitude: longitude,
  );

  static bool contains(double lat, double lon) =>
      kDefaultCity.containsApprox(lat, lon);
}
