import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/error_state.dart';
import '../../data/models/place.dart';

final placeByIdProvider = FutureProvider.family<PlaceDetail, String>((ref, id) {
  return ref.watch(placesRepositoryProvider).byId(id);
});

class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(placeByIdProvider(placeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Место')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(placeByIdProvider(placeId)),
        ),
        data: (detail) {
          final place = detail.place;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(placeByIdProvider(placeId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  place.name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                if (place.address != null && place.address!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    place.address!,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.ratingGold, size: 22),
                    const SizedBox(width: 4),
                    Text(
                      place.reviewsCount > 0
                          ? '${place.ratingAvg.toStringAsFixed(1)} · ${place.reviewsCount} отз.'
                          : 'Пока нет отзывов',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ],
                ),
                if (detail.upcomingEvents.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const Text(
                    'Скоро здесь',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ...detail.upcomingEvents.map(
                    (e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(formatEventDateTime(e.startAt)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                      onTap: () => context.push('/events/${e.id}'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Отзывы',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (detail.reviews.isEmpty)
                  const Text(
                    'Пока тихо. Оставьте отзыв после визита на событии',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  ...detail.reviews.map((r) => _ReviewTile(review: r)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final PlaceReview review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                url: review.reviewerAvatarUrl,
                name: review.reviewerName,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.reviewerName ?? 'Гость',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= review.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 14,
                      color: i <= review.stars ? AppColors.ratingGold : AppColors.textTertiary,
                    ),
                ],
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!, style: const TextStyle(height: 1.4)),
          ],
          if (review.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (c, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: Env.resolveMediaUrl(review.photos[i]),
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
