import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has acknowledged the Terms of Use / Privacy Policy
/// in-app (App Store Guideline 1.2 requires an explicit acceptance step
/// before registration, not just a passive link).
abstract final class TermsAcceptance {
  static const _key = 'terms_accepted_v1';

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
