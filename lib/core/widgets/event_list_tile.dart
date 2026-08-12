import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/models/enums.dart';
import '../../data/models/event.dart';
import '../../data/models/user.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../../features/monetization/monetization_actions.dart';
import 'avatar.dart';
import 'rating_badge.dart';

class EventListTile extends ConsumerStatefulWidget {
  const EventListTile({super.key, required this.event, this.onTap, this.onFavoriteChanged});

  final Event event;
  final VoidCallback? onTap;

  /// Called after a successful favorite toggle so the parent list (e.g. the
  /// favorites screen itself) can refresh. Optional - most callers don't
  /// need it since [Event.isFavorite] already drives the icon locally.
  final VoidCallback? onFavoriteChanged;

  @override
  ConsumerState<EventListTile> createState() => _EventListTileState();
}

class _EventListTileState extends ConsumerState<EventListTile> {
  bool? _favoriteOverride;
  bool _toggling = false;

  Future<void> _toggleFavorite() async {
    if (_toggling) return;
    final next = !(_favoriteOverride ?? widget.event.isFavorite);
    setState(() {
      _toggling = true;
      _favoriteOverride = next;
    });
    try {
      await ref.read(eventRepositoryProvider).setFavorite(widget.event.id, next);
      widget.onFavoriteChanged?.call();
    } catch (_) {
      if (mounted) setState(() => _favoriteOverride = !next);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isFavorite = _favoriteOverride ?? event.isFavorite;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: event.coverPhoto == null
                      ? Container(
                          width: 100,
                          height: 100,
                          color: AppColors.surface,
                          child: const Icon(Icons.image_not_supported_outlined,
                              color: AppColors.textTertiary, size: 20),
                        )
                      : CachedNetworkImage(
                          imageUrl: Env.resolveMediaUrl(event.coverPhoto!),
                          width: 100,
                          height: 100,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(width: 100, height: 100, color: AppColors.surface),
                          errorWidget: (c, u, e) => Container(
                            width: 100,
                            height: 100,
                            color: AppColors.surface,
                            child: const Icon(Icons.image_not_supported_outlined,
                                color: AppColors.textTertiary, size: 20),
                          ),
                        ),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          event.isTakeaway ? Icons.restaurant : Icons.person,
                          size: 11,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          event.seatsBadgeLabel,
                          style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (event.isActivelyBoosted) ...[
                        const SizedBox(width: 6),
                        BoostedBadge(compact: true, until: event.boostedUntil),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatEventWindow(event.startAt, event.endAt),
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          event.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        event.priceLabel,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Flexible(
                        child: Text(
                          '  ·  ${event.isTakeaway ? EventFormat.takeaway.label : event.thresholdLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: event.thresholdReached ? FontWeight.w600 : FontWeight.w400,
                            color: event.thresholdReached
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (event.status != EventStatus.active) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (event.status == EventStatus.cancelled
                                    ? AppColors.danger
                                    : event.status == EventStatus.pendingReview
                                        ? AppColors.warning
                                        : AppColors.textSecondary)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            event.status.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: event.status == EventStatus.cancelled
                                  ? AppColors.danger
                                  : event.status == EventStatus.pendingReview
                                      ? AppColors.warning
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (event.goingSocialLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (event.friendsGoing.isNotEmpty) ...[
                          SizedBox(
                            width: 18.0 + (event.friendsGoing.length - 1) * 12.0,
                            height: 18,
                            child: Stack(
                              children: [
                                for (var i = 0; i < event.friendsGoing.length; i++)
                                  Positioned(
                                    left: i * 12.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.white, width: 1),
                                      ),
                                      child: UserAvatar(
                                        url: event.friendsGoing[i].avatarUrl,
                                        name: event.friendsGoing[i].name,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            event.goingSocialLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                  RatingBadge(
                    score: event.host.displayHostRating,
                    reviewsCount: event.host.displayHostReviewsCount,
                    compact: true,
                  ),
                      if (event.host.hasActiveOrganizerPro) ...[
                        const SizedBox(width: 6),
                        const OrganizerProBadge(compact: true),
                      ],
                      if (event.host.isAuthorOfMonth) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Автор месяца',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ] else if (event.host.isTalentAuthor) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Талант',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      if (event.host.badges.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: _HostMedals(badges: event.host.badges),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: _toggleFavorite,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  size: 22,
                  color: isFavorite ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact medal icons from host achievements (max 3).
class _HostMedals extends StatelessWidget {
  const _HostMedals({required this.badges});

  final List<Badge> badges;

  @override
  Widget build(BuildContext context) {
    final shown = badges.take(3).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final b in shown)
          Tooltip(
            message: b.title,
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(b.icon, style: const TextStyle(fontSize: 14, height: 1)),
            ),
          ),
      ],
    );
  }
}
