import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/env.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/report_dialog.dart';
import '../../core/widgets/tag_chip.dart';
import '../../data/models/application.dart';
import '../../data/models/enums.dart';
import '../../data/models/event.dart';
import '../../data/models/event_stickers.dart';
import '../chat/chats_providers.dart';
import '../monetization/monetization_actions.dart';
import 'events_providers.dart';

String _createStoryPathForEvent(Event event) {
  final cover = event.coverPhoto ??
      (event.photos.isNotEmpty ? event.photos.first : null);
  return Uri(
    path: '/create',
    queryParameters: {
      'mode': 'story',
      if (event.place != null) 'placeId': event.place!.id,
      if (event.place != null) 'placeName': event.place!.name,
      if (event.place?.address != null && event.place!.address!.isNotEmpty)
        'placeAddress': event.place!.address!,
      if (event.title.trim().isNotEmpty) 'text': event.title.trim(),
      if (cover != null && cover.isNotEmpty) 'imageUrl': cover,
    },
  ).toString();
}

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen>
    with WidgetsBindingObserver {
  bool _applying = false;
  bool _togglingFavorite = false;
  bool? _favoriteOverride;
  Timer? _livePoll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Host may have accepted while this screen (or its providers) stayed cached
    // as PENDING - refresh so the guest CTA flips to "Открыть чат".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshEvent());
      unawaited(ref.read(eventRepositoryProvider).recordView(widget.eventId));
      _startLivePoll();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _livePoll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshEvent());
      _startLivePoll();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _livePoll?.cancel();
      _livePoll = null;
    }
  }

  void _startLivePoll() {
    _livePoll?.cancel();
    // Soft live update while the card is open (accept / guest count / chat).
    _livePoll = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      unawaited(_refreshEvent());
    });
  }

  Future<void> _refreshEvent() async {
    ref.invalidate(eventByIdProvider(widget.eventId));
    final signedIn = ref.read(authStateProvider) != null;
    final futures = <Future>[
      ref.read(eventByIdProvider(widget.eventId).future),
    ];
    if (signedIn) {
      ref.invalidate(myApplicationsProvider);
      ref.invalidate(chatsProvider);
      ref.invalidate(eventApplicationsProvider(widget.eventId));
      ref.invalidate(hostedPendingApplicationsProvider);
      futures.add(ref.read(myApplicationsProvider.future));
    }
    await Future.wait(futures);
  }

  bool _requireSignIn() {
    if (ref.read(authStateProvider) != null) return true;
    context.push('/welcome');
    return false;
  }

  Future<void> _apply(Event event, {PickupMethod? pickupMethod}) async {
    if (!_requireSignIn()) return;
    setState(() => _applying = true);
    try {
      await ref.read(eventRepositoryProvider).apply(event.id, pickupMethod: pickupMethod);
      ref.invalidate(myApplicationsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(event.isTakeaway ? 'Заказ оформлен' : 'Заявка отправлена')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось отправить заявку'))),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  /// Takeaway orders need the guest to pick up vs. delivery before the order
  /// is placed - asked via a bottom sheet instead of a plain apply button.
  Future<void> _chooseTakeawayPickup(Event event) async {
    if (!_requireSignIn()) return;
    final choice = await showModalBottomSheet<PickupMethod>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Как заберёте заказ?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.storefront_outlined, color: AppColors.primary),
                title: const Text('Заберу сам'),
                subtitle: const Text('Самовывоз по указанному адресу'),
                onTap: () => Navigator.pop(sheetContext, PickupMethod.pickupOnly),
              ),
              ListTile(
                leading: const Icon(Icons.delivery_dining_outlined, color: AppColors.primary),
                title: const Text('Мне нужна доставка'),
                subtitle: const Text('Договоритесь с хозяином о доставке в чате'),
                onTap: () => Navigator.pop(sheetContext, PickupMethod.meetAtDoor),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _apply(event, pickupMethod: choice);
  }

  Future<void> _toggleFavorite(Event event) async {
    if (_togglingFavorite) return;
    if (!_requireSignIn()) return;
    final next = !(_favoriteOverride ?? event.isFavorite);
    setState(() {
      _togglingFavorite = true;
      _favoriteOverride = next;
    });
    try {
      await ref.read(eventRepositoryProvider).setFavorite(event.id, next);
      ref.invalidate(myFavoritesProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _favoriteOverride = !next);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Не удалось обновить избранное')));
      }
    } finally {
      if (mounted) setState(() => _togglingFavorite = false);
    }
  }

  Future<void> _shareEvent(Event event) async {
    final link = 'https://pulse.by/events/${event.id}';
    await SharePlus.instance.share(
      ShareParams(text: '${event.title}\n$link'),
    );
  }

  void _openPhotoGallery(List<String> photos, int initialIndex) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: photos.length,
                itemBuilder: (c, i) => InteractiveViewer(
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: Env.resolveMediaUrl(photos[i]),
                      fit: BoxFit.contain,
                      placeholder: (c, u) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (c, u, e) =>
                          const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openChat(Event event) async {
    if (!_requireSignIn()) return;
    try {
      final chatId = event.chatId;
      if (chatId != null && chatId.isNotEmpty) {
        if (!mounted) return;
        context.push('/chat/$chatId');
        return;
      }
      final byEvent = await ref.read(chatRepositoryProvider).byEventId(event.id);
      if (!mounted) return;
      if (byEvent != null) {
        ref.invalidate(chatsProvider);
        context.push('/chat/${byEvent.id}');
        return;
      }
      // Refresh event — chatId is only on GET /events/:id after accept.
      ref.invalidate(eventByIdProvider(event.id));
      final fresh = await ref.read(eventByIdProvider(event.id).future);
      if (!mounted) return;
      if (fresh.chatId != null && fresh.chatId!.isNotEmpty) {
        context.push('/chat/${fresh.chatId}');
        return;
      }
      final me = ref.read(authStateProvider);
      final isHost = me != null && event.host.id == me.id;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHost
                ? 'Чат появится после принятия первой заявки'
                : 'Чат откроется, когда хозяин примет вашу заявку',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось открыть чат'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventByIdProvider(widget.eventId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(eventByIdProvider(widget.eventId)),
        ),
        data: (event) {
          final isFavorite = _favoriteOverride ?? event.isFavorite;
          final remainingSpots = (event.maxGuests - event.currentGuests).clamp(0, event.maxGuests);
          final me = ref.watch(authStateProvider);
          final isHost = me != null && event.host.id == me.id;
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refreshEvent,
                child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 320,
                          width: double.infinity,
                          child: event.coverPhoto == null
                              ? Container(
                                  color: AppColors.surface,
                                  child: const Icon(Icons.image_not_supported_outlined,
                                      color: AppColors.textTertiary, size: 32),
                                )
                              : CachedNetworkImage(
                                  imageUrl: Env.resolveMediaUrl(event.coverPhoto!),
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) => Container(color: AppColors.surface),
                                  errorWidget: (c, u, e) => Container(
                                    color: AppColors.surface,
                                    child: const Icon(Icons.image_not_supported_outlined,
                                        color: AppColors.textTertiary, size: 32),
                                  ),
                                ),
                        ),
                        Positioned(
                          left: 16,
                          top: 56,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person, size: 13, color: AppColors.white),
                                const SizedBox(width: 3),
                                Text(
                                  event.seatsBadgeLabel,
                                  style: const TextStyle(
                                      color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    event.title,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (event.isActivelyBoosted) ...[
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: BoostedBadge(until: event.boostedUntil),
                                  ),
                                ],
                              ],
                            ),
                            if (event.status == EventStatus.pendingReview) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'На проверке: событие скрыто из афиши до одобрения админом',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    formatEventWindow(event.startAt, event.endAt),
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ),
                                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                            if (event.place != null) ...[
                              const SizedBox(height: 12),
                              Material(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => context.push('/places/${event.place!.id}'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.place_outlined,
                                            size: 20, color: AppColors.primaryLight),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                event.place!.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                event.place!.reviewsCount > 0
                                                    ? '★ ${event.place!.ratingAvg.toStringAsFixed(1)} · ${event.place!.reviewsCount} отз.'
                                                    : 'Пока нет отзывов о месте',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right,
                                            color: AppColors.textTertiary),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (!event.isTakeaway) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: event.thresholdReached
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: event.thresholdReached
                                        ? AppColors.success.withValues(alpha: 0.35)
                                        : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      event.thresholdReached
                                          ? Icons.check_circle_outline
                                          : Icons.hourglass_bottom,
                                      size: 18,
                                      color: event.thresholdReached
                                          ? AppColors.success
                                          : AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        event.thresholdReached
                                            ? 'Набралось ${event.minGuests}+ - можно готовить\n${event.currentGuests} из ${event.maxGuests} мест занято'
                                            : 'Набор до старта\n${event.currentGuests} из ${event.minGuests} · ещё ${event.guestsNeededForStart}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: event.thresholdReached
                                              ? AppColors.success
                                              : AppColors.textPrimary,
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            InkWell(
                              onTap: () => context.push('/host/${event.host.id}'),
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        UserAvatar(url: event.host.avatarUrl, size: 40, name: event.host.name),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      formatUserName(event.host.name, event.host.age),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight.w600, fontSize: 13),
                                                    ),
                                                  ),
                                                  if (event.host.hasActiveOrganizerPro) ...[
                                                    const SizedBox(width: 6),
                                                    const OrganizerProBadge(compact: true),
                                                  ],
                                                ],
                                              ),
                                              const Text('Организатор',
                                                  style:
                                                      TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _StatColumn(
                                    icon: Icons.star,
                                    value: event.host.reviewsCount == 0
                                        ? '-'
                                        : event.host.rating.toStringAsFixed(0),
                                    label: event.host.reviewsCount == 0
                                        ? 'нет оценок'
                                        : '/100 · ${event.host.reviewsCount}',
                                  ),
                                  _StatColumn(
                                    icon: Icons.people_outline,
                                    value: event.isTakeaway ? '-' : '$remainingSpots',
                                    label: 'свободно',
                                  ),
                                ],
                              ),
                            ),
                            if (event.tags.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: EventStickers.ordered(event.tags)
                                    .map((t) => TagChip(label: t, outlined: true))
                                    .toList(),
                              ),
                            ],
                            if (event.goingSocialLabel.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  if (event.friendsGoing.isNotEmpty) ...[
                                    SizedBox(
                                      width: 28.0 +
                                          (event.friendsGoing.length - 1) * 18.0,
                                      height: 28,
                                      child: Stack(
                                        children: [
                                          for (var i = 0;
                                              i < event.friendsGoing.length;
                                              i++)
                                            Positioned(
                                              left: i * 18.0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: AppColors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: UserAvatar(
                                                  url: event
                                                      .friendsGoing[i].avatarUrl,
                                                  name: event.friendsGoing[i].name,
                                                  size: 26,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Text(
                                      event.goingSocialLabel,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (isHost) ...[
                              const SizedBox(height: 16),
                              _HostEventStats(eventId: event.id),
                            ],
                            const SizedBox(height: 18),
                            Text(
                              event.description,
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Перед заявкой: адрес и детали встречи уточняются с хозяином в общем чате события после принятия. Отменить участие можно до старта, написав хозяину.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            if (event.photos.length > 1) ...[
                              const SizedBox(height: 20),
                              const Text('Фотографии', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 76,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: event.photos.length.clamp(0, 4),
                                  separatorBuilder: (c, i) => const SizedBox(width: 8),
                                  itemBuilder: (c, i) {
                                    final isLast = i == 3 && event.photos.length > 4;
                                    return GestureDetector(
                                      onTap: () => _openPhotoGallery(event.photos, i),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                          children: [
                                            CachedNetworkImage(
                                              imageUrl: Env.resolveMediaUrl(event.photos[i]),
                                              width: 76,
                                              height: 76,
                                              fit: BoxFit.cover,
                                              placeholder: (c, u) =>
                                                  Container(width: 76, height: 76, color: AppColors.surface),
                                              errorWidget: (c, u, e) =>
                                                  Container(width: 76, height: 76, color: AppColors.surface),
                                            ),
                                            if (isLast)
                                              Container(
                                                width: 76,
                                                height: 76,
                                                color: Colors.black.withValues(alpha: 0.5),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  '+${event.photos.length - 4}',
                                                  style: const TextStyle(
                                                      color: AppColors.white,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            const Text('Условия', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            _ConditionRow(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Стоимость',
                              value: event.isTakeaway
                                  ? '${event.priceLabel} · ${EventFormat.takeaway.label}'
                                  : '${event.priceLabel} с человека',
                            ),
                            _ConditionRow(
                              icon: Icons.groups_outlined,
                              label: 'Формат',
                              value: event.format.label,
                            ),
                            if (event.isTakeaway && event.pickupMethod != null)
                              _ConditionRow(
                                icon: Icons.storefront_outlined,
                                label: 'Получение',
                                value: '${event.pickupMethod!.label} · ${event.pickupAddress ?? event.address}',
                              ),
                            if (event.isTakeaway && event.portionWeightGrams != null)
                              _ConditionRow(
                                icon: Icons.scale_outlined,
                                label: 'Вес порции',
                                value: '~${event.portionWeightGrams} г',
                              ),
                            if (isHost && event.status == EventStatus.active) ...[
                              const SizedBox(height: 20),
                              _PendingApplicationsSection(
                                eventId: event.id,
                                chatId: event.chatId,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton.icon(
                                onPressed: () => showReportDialog(
                                  context,
                                  ref,
                                  targetType: ComplaintTargetType.event,
                                  targetId: event.id,
                                ),
                                icon: const Icon(Icons.flag_outlined, size: 16, color: AppColors.textTertiary),
                                label: const Text('Пожаловаться',
                                    style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ),
              Positioned(
                left: 16,
                top: 8,
                child: SafeArea(
                  child: _CircleIconButton(icon: Icons.arrow_back, alignEnd: false),
                ),
              ),
              Positioned(
                right: 16,
                top: 8,
                child: SafeArea(
                  child: Row(
                    children: [
                      if (isHost) ...[
                        _CircleIconButton(
                          icon: Icons.edit_outlined,
                          onTap: () => context.push('/events/${event.id}/edit'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      _CircleIconButton(
                        icon: isFavorite ? Icons.bookmark : Icons.bookmark_border,
                        color: isFavorite ? AppColors.primary : AppColors.black,
                        onTap: () => _toggleFavorite(event),
                      ),
                      const SizedBox(width: 10),
                      _CircleIconButton(
                        icon: Icons.ios_share,
                        onTap: () => _shareEvent(event),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: eventAsync.maybeWhen(
        data: (event) {
          final me = ref.watch(authStateProvider);
          final isHost = me != null && event.host.id == me.id;
          final completed = event.status == EventStatus.completed;

          if (completed && me != null) {
            return _CompletedEventActions(
              event: event,
              isHost: isHost,
            );
          }

          final myApp = me == null
              ? null
              : ref.watch(myApplicationsProvider).maybeWhen(
                    data: (apps) {
                      for (final a in apps) {
                        if (a.event.id == event.id) return a;
                      }
                      return null;
                    },
                    orElse: () => null,
                  );

          if (isHost) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (event.status == EventStatus.active)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => showPromoteEventSheet(
                            context: context,
                            ref: ref,
                            event: event,
                          ),
                          icon: Icon(
                            Icons.rocket_launch_outlined,
                            size: 18,
                            color: event.isActivelyBoosted
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                          label: Text(
                            event.isActivelyBoosted && event.boostedUntil != null
                                ? 'В топе до ${formatProUntil(event.boostedUntil!)}'
                                : 'Продвинуть в афише',
                            style: TextStyle(
                              color: event.isActivelyBoosted
                                  ? AppColors.success
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openChat(event),
                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                            label: const Text('Общий чат'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.push('/events/${event.id}/edit'),
                            child: const Text('Редактировать'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          if (myApp != null) {
            final accepted = myApp.status == ApplicationStatus.accepted;
            if (accepted) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _openChat(event),
                              child: const Text('Открыть общий чат'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _CircleIconButton(
                            icon: Icons.ios_share,
                            bordered: true,
                            onTap: () => _shareEvent(event),
                          ),
                          const SizedBox(width: 8),
                          _CircleIconButton(
                            icon: Icons.auto_awesome_outlined,
                            bordered: true,
                            onTap: () =>
                                context.push(_createStoryPathForEvent(event)),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () =>
                            context.push(_createStoryPathForEvent(event)),
                        child: const Text('Рассказать в историю'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final label = switch (myApp.status) {
              ApplicationStatus.pending => 'Заявка на рассмотрении',
              ApplicationStatus.accepted => 'Открыть общий чат',
              ApplicationStatus.rejected => 'Заявка отклонена',
            };
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: myApp.status == ApplicationStatus.rejected
                      ? null
                      : () => context.push('/my-orders'),
                  child: Text(label),
                ),
              ),
            );
          }

          final canApply = event.isOpenForApplications && !_applying;
          final applyLabel = _applying
              ? '...'
              : !event.isOpenForApplications
                  ? (event.applyBlockedReason.isEmpty ? 'Недоступно' : event.applyBlockedReason)
                  : (event.isTakeaway ? 'Забронировать' : 'Подать заявку');
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canApply
                          ? () => event.isTakeaway ? _chooseTakeawayPickup(event) : _apply(event)
                          : null,
                      child: Text(applyLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CircleIconButton(
                    icon: Icons.chat_bubble_outline,
                    bordered: true,
                    onTap: () => _openChat(event),
                  ),
                ],
              ),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }
}

/// After the waiting window: confirm attendance, then rate host/guests.
class _CompletedEventActions extends ConsumerWidget {
  const _CompletedEventActions({
    required this.event,
    required this.isHost,
  });

  final Event event;
  final bool isHost;

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    try {
      final known = event.chatId;
      if (known != null && known.isNotEmpty) {
        if (!context.mounted) return;
        context.push('/chat/$known');
        return;
      }
      final byEvent = await ref.read(chatRepositoryProvider).byEventId(event.id);
      if (!context.mounted) return;
      if (byEvent != null) {
        ref.invalidate(chatsProvider);
        context.push('/chat/${byEvent.id}');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHost
                ? 'Чат появится после принятия первой заявки'
                : 'Чат откроется, когда хозяин примет вашу заявку',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось открыть чат'))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isHost) {
      final appsAsync = ref.watch(eventApplicationsProvider(event.id));
      return appsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (apps) {
          final accepted = apps
              .where((a) => a.status == ApplicationStatus.accepted)
              .toList();
          if (accepted.isEmpty) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Событие завершено. Заявок для оценки нет.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _showHostRateSheet(context, ref, accepted),
                    child: const Text('1. Подтвердить визит → 2. Оценить гостей'),
                  ),
                  if (event.place != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/rate-place/${event.id}?placeId=${event.place!.id}',
                      ),
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: const Text('Оценить место'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    }

    final appsAsync = ref.watch(myApplicationsProvider);
    return appsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (apps) {
        EventApplication? mine;
        for (final a in apps) {
          if (a.event.id == event.id && a.status == ApplicationStatus.accepted) {
            mine = a;
            break;
          }
        }
        if (mine == null) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Событие завершено',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final canConfirm = mine.guestConfirmedAt == null;
        final waitingHost =
            mine.guestConfirmedAt != null && mine.hostConfirmedAt == null;
        final canRate = mine.mutualAttendanceConfirmed;
        final placeId = event.place?.id;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canConfirm
                            ? () => _confirmGuest(context, ref, mine!.id)
                            : canRate
                                ? () => context.push(
                                      '/rate/${event.id}?targetId=${event.host.id}&role=host',
                                    )
                                : null,
                        child: Text(
                          canConfirm
                              ? '1. Я был(а) - подтвердить визит'
                              : canRate
                                  ? '2. Оценить хозяина'
                                  : waitingHost
                                      ? 'Ждём подтверждения хозяина'
                                      : 'Визит подтверждён',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CircleIconButton(
                      icon: Icons.chat_bubble_outline,
                      bordered: true,
                      onTap: () => _openChat(context, ref),
                    ),
                  ],
                ),
                if (placeId != null && canRate) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/rate-place/${event.id}?placeId=$placeId',
                      ),
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: const Text('Оценить место'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmGuest(BuildContext context, WidgetRef ref, String applicationId) async {
    try {
      await ref.read(eventRepositoryProvider).confirmAttendance(applicationId);
      ref.invalidate(myApplicationsProvider);
      ref.invalidate(eventApplicationsProvider(event.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Визит подтверждён. Когда хозяин подтвердит - оцените друг друга.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _showHostRateSheet(
    BuildContext context,
    WidgetRef ref,
    List<EventApplication> accepted,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const Text(
                'Гости',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Сначала подтвердите визит с обеих сторон, затем оцените гостя. '
                'Если гость не пришёл - отметьте неявку.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ...accepted.map((a) {
                final confirmedByHost = a.hostConfirmedAt != null;
                final mutual = a.mutualAttendanceConfirmed;
                final noShow = a.isNoShow;
                final name = a.applicant.name.isEmpty ? 'Гость' : a.applicant.name;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(name),
                  subtitle: Text(
                    noShow
                        ? 'Неявка'
                        : mutual
                            ? 'Можно оценить'
                            : confirmedByHost
                                ? 'Ждём подтверждения гостя'
                                : 'Подтвердите, что гость был',
                    style: TextStyle(
                      fontSize: 12,
                      color: noShow ? AppColors.danger : null,
                    ),
                  ),
                  trailing: noShow
                      ? TextButton(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(eventRepositoryProvider)
                                  .clearNoShow(a.id);
                              ref.invalidate(eventApplicationsProvider(event.id));
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(apiErrorMessage(e))),
                                );
                              }
                            }
                          },
                          child: const Text('Снять неявку'),
                        )
                      : mutual
                          ? TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                context.push(
                                  '/rate/${event.id}?targetId=${a.applicant.id}&role=guest',
                                );
                              },
                              child: const Text('Оценить'),
                            )
                          : confirmedByHost
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          await ref
                                              .read(eventRepositoryProvider)
                                              .confirmAttendance(a.id);
                                          ref.invalidate(eventApplicationsProvider(event.id));
                                          if (ctx.mounted) Navigator.pop(ctx);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(apiErrorMessage(e))),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text('Был'),
                                    ),
                                    if (!event.isTakeaway)
                                      TextButton(
                                        onPressed: () async {
                                          try {
                                            await ref
                                                .read(eventRepositoryProvider)
                                                .markNoShow(a.id);
                                            ref.invalidate(eventApplicationsProvider(event.id));
                                            if (ctx.mounted) Navigator.pop(ctx);
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(apiErrorMessage(e))),
                                              );
                                            }
                                          }
                                        },
                                        child: const Text(
                                          'Не пришёл',
                                          style: TextStyle(color: AppColors.danger),
                                        ),
                                      ),
                                  ],
                                ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Lets the host accept/reject pending applications right from the event
/// they're already on - this is where the "new application" notification
/// sends them, and previously there was nowhere to act on it from here.
class _PendingApplicationsSection extends ConsumerStatefulWidget {
  const _PendingApplicationsSection({
    required this.eventId,
    this.chatId,
  });

  final String eventId;
  final String? chatId;

  @override
  ConsumerState<_PendingApplicationsSection> createState() =>
      _PendingApplicationsSectionState();
}

class _PendingApplicationsSectionState extends ConsumerState<_PendingApplicationsSection> {
  final Set<String> _busyIds = {};

  Future<void> _respond(EventApplication application, ApplicationStatus status) async {
    setState(() => _busyIds.add(application.id));
    try {
      final chatId = await ref
          .read(eventRepositoryProvider)
          .respondToApplication(application.id, status);
      ref.invalidate(eventApplicationsProvider(widget.eventId));
      ref.invalidate(eventByIdProvider(widget.eventId));
      ref.invalidate(chatsProvider);
      ref.invalidate(myApplicationsProvider);
      ref.invalidate(hostedPendingApplicationsProvider);
      if (!mounted) return;
      if (status == ApplicationStatus.accepted) {
        final resolvedChatId = chatId ??
            (await ref.read(chatRepositoryProvider).byEventId(widget.eventId))?.id;
        if (!mounted) return;
        if (resolvedChatId != null) {
          context.push('/chat/$resolvedChatId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заявка принята')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка отклонена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Не удалось обновить заявку'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(application.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(eventApplicationsProvider(widget.eventId));
    return appsAsync.maybeWhen(
      data: (applications) {
        final pending =
            applications.where((a) => a.status == ApplicationStatus.pending).toList();
        final accepted =
            applications.where((a) => a.status == ApplicationStatus.accepted).toList();
        if (pending.isEmpty && accepted.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pending.isNotEmpty) ...[
                Text(
                  'Заявки (${pending.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...pending.map((a) {
                  final busy = _busyIds.contains(a.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(url: a.applicant.avatarUrl, size: 36, name: a.applicant.name),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatUserName(a.applicant.name, a.applicant.age),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  if (a.applicant.activity.hasNoShowSignal)
                                    Text(
                                      a.applicant.activity.noShowLabel,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (a.message != null && a.message!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(a.message!, style: const TextStyle(fontSize: 13)),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    busy ? null : () => _respond(a, ApplicationStatus.rejected),
                                child: const Text('Отклонить'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    busy ? null : () => _respond(a, ApplicationStatus.accepted),
                                child: Text(busy ? '...' : 'Принять'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (accepted.isNotEmpty) ...[
                if (pending.isNotEmpty) const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Участники',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          final known = widget.chatId;
                          if (known != null && known.isNotEmpty) {
                            ref.invalidate(chatsProvider);
                            context.push('/chat/$known');
                            return;
                          }
                          final chat = await ref
                              .read(chatRepositoryProvider)
                              .byEventId(widget.eventId);
                          if (!context.mounted) return;
                          if (chat != null) {
                            ref.invalidate(chatsProvider);
                            context.push('/chat/${chat.id}');
                            return;
                          }
                          context.go('/home/chats');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Общий чат появится после принятия гостя',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                apiErrorMessage(e, fallback: 'Не удалось открыть чат'),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Общий чат'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...accepted.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        UserAvatar(url: a.applicant.avatarUrl, size: 36, name: a.applicant.name),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatUserName(a.applicant.name, a.applicant.age),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (a.applicant.activity.hasNoShowSignal)
                                Text(
                                  a.applicant.activity.noShowLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.danger,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          a.isNoShow ? 'Неявка' : 'Принят',
                          style: TextStyle(
                            fontSize: 12,
                            color: a.isNoShow ? AppColors.danger : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _HostEventStats extends ConsumerWidget {
  const _HostEventStats({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(eventStatsProvider(eventId));
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        final until = stats.boostedUntil;
        final boostLabel = stats.isBoosted && until != null
            ? 'В топе до ${formatEventDateTime(until)}'
            : (stats.isBoosted ? 'В топе' : null);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Статистика',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      value: '${stats.viewCount}',
                      label: 'просмотров',
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      value: '${stats.applicationsCount}',
                      label: 'заявок',
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      value: '${stats.acceptedCount}',
                      label: 'идут',
                    ),
                  ),
                ],
              ),
              if (boostLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  boostLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    this.onTap,
    this.color = AppColors.black,
    this.alignEnd = true,
    this.bordered = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final bool alignEnd;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: bordered ? Border.all(color: AppColors.border) : null,
        boxShadow: bordered ? null : const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Icon(icon, size: 20, color: color),
    );
    return InkWell(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      borderRadius: BorderRadius.circular(20),
      child: button,
    );
  }
}
