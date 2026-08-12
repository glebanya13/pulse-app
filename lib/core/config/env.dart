import 'dart:io' show Platform;

/// Runtime configuration. Values are injected via --dart-define so real
/// secrets never get committed to the repo.
///
/// Run with, e.g.:
/// flutter run \
///   --dart-define=YANDEX_MAPKIT_API_KEY=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
///   --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
abstract final class Env {
  static const String yandexMapkitApiKey = String.fromEnvironment(
    'YANDEX_MAPKIT_API_KEY',
    // Prefer --dart-define in CI/release. Default kept so Xcode Archive
    // without dart-define still gets a working map during TestFlight.
    defaultValue: 'ba890b89-8791-408b-804b-2d9e8cd23158',
  );

  /// HTTP Geocoder / place search (not the same product as MapKit).
  static const String yandexGeocoderApiKey = String.fromEnvironment(
    'YANDEX_GEOCODER_API_KEY',
    defaultValue: 'f18e246e-5146-4ee8-8540-7acaf12ed640',
  );

  /// Geosuggest - address/org autocomplete (`types=biz` finds clubs, cafes…).
  static const String yandexGeosuggestApiKey = String.fromEnvironment(
    'YANDEX_GEOSUGGEST_API_KEY',
    defaultValue: '8a5162e2-a09b-41cc-827f-97d6ef3a8926',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Building from Xcode's own Run button (not `flutter run`/`flutter
    // build` from the CLI) never passes --dart-define, so this default has
    // to be reachable on its own. Production API behind Caddy + Let's Encrypt.
    defaultValue: 'https://pulse-app.by/api/v1',
  );

  /// While true, screens read from [MockRepository]s instead of hitting the
  /// backend, so the UI is fully demoable before the API is wired up.
  /// Widget tests always use mocks (no network in the test sandbox).
  static bool get useMockData {
    const fromDefine = bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);
    if (fromDefine) return true;
    return Platform.environment.containsKey('FLUTTER_TEST');
  }

  static bool get hasMapkitKey => yandexMapkitApiKey.isNotEmpty;

  static bool get hasGeocoderKey => yandexGeocoderApiKey.isNotEmpty;

  static bool get hasGeosuggestKey => yandexGeosuggestApiKey.isNotEmpty;

  /// Public legal pages (served by the backend static `public/` folder).
  static const String privacyPolicyUrl = 'https://pulse-app.by/privacy.html';
  static const String termsOfUseUrl = 'https://pulse-app.by/terms.html';
  static const String supportUrl = 'https://pulse-app.by/support.html';
  static const String deleteAccountUrl = 'https://pulse-app.by/delete-account.html';

  /// `apiBaseUrl` minus the `/api/v1` suffix - uploaded files are served
  /// from the origin root (`/uploads/...`), not under the API prefix.
  static String get apiOrigin {
    final uri = Uri.parse(apiBaseUrl);
    return '${uri.scheme}://${uri.authority}';
  }

  /// The backend returns uploaded photo/avatar URLs as origin-relative paths
  /// (e.g. `/uploads/xyz.jpg`); mock data and any future CDN use full URLs.
  /// Route every image through this before handing it to a network image
  /// widget so both cases work.
  static String resolveMediaUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$apiOrigin$url';
  }
}
