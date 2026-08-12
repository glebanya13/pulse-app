import 'package:flutter/services.dart';

/// Digits only.
String _digits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

/// Normalizes phone input to E.164 (`+` + country code + national number).
///
/// Accepts any country. Soft helpers for local BY / RU shorthand:
/// - `29…` / `33…` (9 digits) → `+375…`
/// - `80XXXXXXXXX` → `+375…`
/// - `8XXXXXXXXXX` (RU) → `+7…`
String normalizePhone(String raw) {
  final trimmed = raw.trim();
  var digits = _digits(trimmed);
  if (digits.isEmpty) return trimmed;

  // Belarus legacy trunk: 80 XX XXXXXXX
  if (digits.startsWith('80') && digits.length == 11) {
    return '+375${digits.substring(2)}';
  }
  // Russia trunk: 8 XXX XXX XX XX
  if (digits.startsWith('8') && digits.length == 11) {
    return '+7${digits.substring(1)}';
  }
  // Local BY mobile without country code
  if (digits.length == 9 && RegExp(r'^(25|29|33|44)').hasMatch(digits)) {
    return '+375$digits';
  }

  // Already international (with or without leading + in raw)
  if (digits.length >= 8 && digits.length <= 15 && !digits.startsWith('0')) {
    return '+$digits';
  }

  if (trimmed.startsWith('+') && digits.isNotEmpty) {
    return '+$digits';
  }
  return trimmed;
}

/// Alias kept for existing call sites.
String normalizeRuPhone(String raw) => normalizePhone(raw);

/// ITU E.164: `+` and 8–15 digits, first digit of country code 1–9.
bool isPlausiblePhone(String phone) {
  final n = normalizePhone(phone);
  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(n);
}

/// Light international formatter: keeps `+` and digits, soft grouping.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = _digits(newValue.text);
    if (d.isEmpty) {
      return const TextEditingValue(
        text: '+',
        selection: TextSelection.collapsed(offset: 1),
      );
    }
    if (d.length > 15) d = d.substring(0, 15);

    final text = _formatInternational(d);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String _formatInternational(String d) {
    // BY +375 XX XXX-XX-XX
    if (d.startsWith('375')) {
      final buf = StringBuffer('+375');
      final national = d.length > 3 ? d.substring(3) : '';
      for (var i = 0; i < national.length; i++) {
        if (i == 0 || i == 2) buf.write(' ');
        if (i == 5 || i == 7) buf.write('-');
        buf.write(national[i]);
      }
      return buf.toString();
    }
    // RU +7 XXX XXX-XX-XX
    if (d.startsWith('7')) {
      final buf = StringBuffer('+7');
      final national = d.length > 1 ? d.substring(1) : '';
      for (var i = 0; i < national.length; i++) {
        if (i == 0 || i == 3) buf.write(' ');
        if (i == 6 || i == 8) buf.write('-');
        buf.write(national[i]);
      }
      return buf.toString();
    }
    // Other: +digits with a space after the first 1–3 digits
    final ccLen = d.length >= 3 ? 3 : d.length;
    if (d.length <= ccLen) return '+$d';
    return '+${d.substring(0, ccLen)} ${d.substring(ccLen)}';
  }
}

/// Backward-compatible alias used by login/register screens.
class RuPhoneInputFormatter extends PhoneInputFormatter {}
