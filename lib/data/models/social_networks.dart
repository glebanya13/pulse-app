/// Known social networks a user can publish on their profile.
class SocialNetworks {
  SocialNetworks._();

  static const instagram = 'instagram';
  static const telegram = 'telegram';
  static const vk = 'vk';
  static const facebook = 'facebook';
  static const youtube = 'youtube';
  static const tiktok = 'tiktok';
  static const ok = 'ok';

  static const keys = [
    instagram,
    telegram,
    vk,
    facebook,
    youtube,
    tiktok,
    ok,
  ];

  static const labels = {
    instagram: 'Instagram',
    telegram: 'Telegram',
    vk: 'ВКонтакте',
    facebook: 'Facebook',
    youtube: 'YouTube',
    tiktok: 'TikTok',
    ok: 'Одноклассники',
  };

  static const hints = {
    instagram: 'username или ссылка',
    telegram: '@username или t.me/...',
    vk: 'username или ссылка',
    facebook: 'ссылка или username',
    youtube: '@channel или ссылка',
    tiktok: '@username или ссылка',
    ok: 'ссылка на профиль',
  };

  /// Drop empty values and unknown keys.
  static Map<String, String> sanitize(Map<String, String> raw) {
    final out = <String, String>{};
    for (final key in keys) {
      final value = raw[key]?.trim() ?? '';
      if (value.isNotEmpty) out[key] = value.length > 200 ? value.substring(0, 200) : value;
    }
    return out;
  }

  /// Build a https URL suitable for [url_launcher].
  static Uri? launchUri(String key, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final lower = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return Uri.tryParse(value);
    }

    switch (key) {
      case telegram:
        final handle = value.startsWith('@') ? value.substring(1) : value.replaceFirst(RegExp(r'^t\.me/'), '');
        return Uri.parse('https://t.me/$handle');
      case instagram:
        final handle = value.startsWith('@') ? value.substring(1) : value;
        return Uri.parse('https://instagram.com/$handle');
      case vk:
        final handle = value.startsWith('@') ? value.substring(1) : value;
        return Uri.parse(handle.startsWith('id') || handle.contains('/')
            ? 'https://vk.com/$handle'
            : 'https://vk.com/$handle');
      case facebook:
        final handle = value.startsWith('@') ? value.substring(1) : value;
        return Uri.parse('https://facebook.com/$handle');
      case youtube:
        final handle = value.startsWith('@') ? value : '@$value';
        return Uri.parse('https://youtube.com/$handle');
      case tiktok:
        final handle = value.startsWith('@') ? value : '@$value';
        return Uri.parse('https://www.tiktok.com/$handle');
      case ok:
        return Uri.parse(value.contains('ok.ru') ? 'https://$value' : 'https://ok.ru/$value');
      default:
        return Uri.tryParse('https://$value');
    }
  }
}
