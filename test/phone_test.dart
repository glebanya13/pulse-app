import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/utils/phone.dart';

void main() {
  group('normalizePhone', () {
    test('BY local 9 digits', () {
      expect(normalizePhone('291112233'), '+375291112233');
    });

    test('BY with 375', () {
      expect(normalizePhone('375291112233'), '+375291112233');
    });

    test('BY legacy 80', () {
      expect(normalizePhone('80291112233'), '+375291112233');
    });

    test('BY formatted', () {
      expect(normalizePhone('+375 29 111-22-33'), '+375291112233');
    });

    test('RU +7', () {
      expect(normalizePhone('+7 900 123-45-67'), '+79001234567');
    });

    test('RU trunk 8', () {
      expect(normalizePhone('89001234567'), '+79001234567');
    });

    test('other country +48', () {
      expect(normalizePhone('+48 500 100 200'), '+48500100200');
    });
  });

  group('isPlausiblePhone', () {
    test('accepts BY', () {
      expect(isPlausiblePhone('+375 29 111-22-33'), isTrue);
      expect(isPlausiblePhone('+375331112233'), isTrue);
    });

    test('accepts RU', () {
      expect(isPlausiblePhone('+7 900 123-45-67'), isTrue);
    });

    test('accepts other countries', () {
      expect(isPlausiblePhone('+48500100200'), isTrue);
      expect(isPlausiblePhone('+12025550123'), isTrue);
    });

    test('rejects short', () {
      expect(isPlausiblePhone('123'), isFalse);
    });
  });
}
