import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/env.dart';
import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.url, required this.size, this.name});

  final String? url;
  final double size;
  final String? name;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.surface,
        child: Text(
          (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?',
          style: TextStyle(fontSize: size * 0.4, color: AppColors.textSecondary),
        ),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: Env.resolveMediaUrl(url!),
        width: size,
        height: size,
        memCacheWidth: (size * 2).round().clamp(48, 256),
        memCacheHeight: (size * 2).round().clamp(48, 256),
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: AppColors.surface,
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          color: AppColors.surface,
          child: Icon(Icons.person, size: size * 0.5, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
