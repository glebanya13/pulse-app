import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/social_networks.dart';
import '../theme/app_colors.dart';

/// Row of tappable social-network chips for a public/own profile.
class SocialLinksRow extends StatelessWidget {
  const SocialLinksRow({super.key, required this.links});

  final Map<String, String> links;

  @override
  Widget build(BuildContext context) {
    final entries = SocialNetworks.keys
        .where((k) => (links[k] ?? '').trim().isNotEmpty)
        .map((k) => MapEntry(k, links[k]!.trim()))
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Соцсети', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries.map((e) {
            final label = SocialNetworks.labels[e.key] ?? e.key;
            return ActionChip(
              avatar: Icon(_iconFor(e.key), size: 18, color: AppColors.primary),
              label: Text(label),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              onPressed: () => _open(context, e.key, e.value),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _iconFor(String key) {
    switch (key) {
      case SocialNetworks.instagram:
        return Icons.camera_alt_outlined;
      case SocialNetworks.telegram:
        return Icons.send_outlined;
      case SocialNetworks.vk:
        return Icons.group_outlined;
      case SocialNetworks.facebook:
        return Icons.facebook;
      case SocialNetworks.youtube:
        return Icons.play_circle_outline;
      case SocialNetworks.tiktok:
        return Icons.music_note_outlined;
      case SocialNetworks.ok:
        return Icons.people_outline;
      default:
        return Icons.link;
    }
  }

  Future<void> _open(BuildContext context, String key, String value) async {
    final uri = SocialNetworks.launchUri(key, value);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть $uri')),
      );
    }
  }
}
