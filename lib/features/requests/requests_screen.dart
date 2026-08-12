import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/rating_badge.dart';
import '../../core/widgets/report_dialog.dart';
import '../../data/models/complaint.dart';
import '../../data/models/enums.dart';
import '../../data/models/guest_request.dart';
import 'requests_providers.dart';

class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск по запросам',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Запросы'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchController.clear();
            }),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Общий'), Tab(text: 'Персональный'), Tab(text: 'Поддержка')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RequestsList(type: RequestType.general, query: _searchController.text),
          _RequestsList(type: RequestType.personal, query: _searchController.text),
          const _SupportPanel(),
        ],
      ),
      bottomNavigationBar: _tabController.index == 2
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.black),
                  onPressed: () => context.push('/requests/create'),
                  child: const Text('Создать запрос'),
                ),
              ),
            ),
    );
  }
}

class _RequestsList extends ConsumerWidget {
  const _RequestsList({required this.type, required this.query});

  final RequestType type;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(requestsProvider(type));

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(requestsProvider(type)),
      ),
      data: (allRequests) {
        final requests = query.trim().isEmpty
            ? allRequests
            : allRequests
                .where((r) => r.title.toLowerCase().contains(query.trim().toLowerCase()))
                .toList();
        if (requests.isEmpty) {
          return EmptyState(
            icon: Icons.forum_outlined,
            title: query.trim().isEmpty ? 'Пока нет запросов' : 'Ничего не найдено',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(requestsProvider(type).future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (c, i) => _RequestCard(request: requests[i]),
          ),
        );
      },
    );
  }
}

class _SupportPanel extends ConsumerWidget {
  const _SupportPanel();

  Future<void> _openSupportChat(BuildContext context) async {
    final uri = Uri.parse('https://t.me/pulse_by_bot');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Не удалось открыть Telegram')));
    }
  }

  Future<void> _newRequest(BuildContext context, WidgetRef ref) async {
    final me = ref.read(currentUserProvider);
    await showReportDialog(context, ref, targetType: ComplaintTargetType.support, targetId: me.id);
    ref.invalidate(myComplaintsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(myComplaintsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: OutlinedButton.icon(
            onPressed: () => _openSupportChat(context),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Написать в Telegram'),
          ),
        ),
        Expanded(
          child: complaintsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(myComplaintsProvider),
            ),
            data: (complaints) {
              if (complaints.isEmpty) {
                return const EmptyState(
                  icon: Icons.support_agent_outlined,
                  title: 'Пока нет обращений в поддержку',
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(myComplaintsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: complaints.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (c, i) => _ComplaintCard(complaint: complaints[i]),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ElevatedButton(
              onPressed: () => _newRequest(context, ref),
              child: const Text('Новое обращение'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final color = switch (complaint.status) {
      ComplaintStatus.open => AppColors.textSecondary,
      ComplaintStatus.resolved => AppColors.success,
      ComplaintStatus.dismissed => AppColors.textTertiary,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  complaint.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  complaint.status.label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatEventDateTime(complaint.createdAt),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request});

  final GuestRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final isMine = request.author.id == me.id;

    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _OffersSheetContent(requestId: request.id),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: request.coverPhoto == null
                  ? Container(
                      width: 64,
                      height: 64,
                      color: AppColors.surface,
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: AppColors.textTertiary, size: 18),
                    )
                  : CachedNetworkImage(
                      imageUrl: Env.resolveMediaUrl(request.coverPhoto!),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => Container(width: 64, height: 64, color: AppColors.surface),
                      errorWidget: (c, u, e) => Container(width: 64, height: 64, color: AppColors.surface),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    formatEventWindow(request.requestedAt, request.requestedEndAt),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  if (request.address != null)
                    Text(request.address!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(
                    'Бюджет: ${request.budgetLabel}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (request.type == RequestType.personal && request.targetHost != null)
                        Expanded(
                          child: Text(
                            'Предложено: ${request.targetHost!.name}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        )
                      else
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.people_outline, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  isMine
                                      ? (request.offers.isEmpty
                                          ? 'Пока нет откликов'
                                          : 'Откликнулось ${request.offers.length}')
                                      : 'Нажмите для отклика',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        request.status.label,
                        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OffersSheetContent extends ConsumerStatefulWidget {
  const _OffersSheetContent({required this.requestId});

  final String requestId;

  @override
  ConsumerState<_OffersSheetContent> createState() => _OffersSheetContentState();
}

class _OffersSheetContentState extends ConsumerState<_OffersSheetContent> {
  late Future<GuestRequest> _future = ref.read(requestRepositoryProvider).byId(widget.requestId);
  String? _busyOfferId;
  bool _submittingOffer = false;
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _reload() {
    ref.invalidate(requestsProvider);
    final next = ref.read(requestRepositoryProvider).byId(widget.requestId);
    setState(() {
      _future = next;
    });
  }

  Future<void> _respond(String offerId, OfferStatus status) async {
    setState(() => _busyOfferId = offerId);
    try {
      await ref.read(requestRepositoryProvider).respondToOffer(offerId, status);
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busyOfferId = null);
    }
  }

  Future<void> _withdraw(String offerId) async {
    setState(() => _busyOfferId = offerId);
    try {
      await ref.read(requestRepositoryProvider).withdrawOffer(offerId);
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _busyOfferId = null);
    }
  }

  Future<void> _submitOffer() async {
    setState(() => _submittingOffer = true);
    try {
      final me = ref.read(currentUserProvider);
      await ref.read(requestRepositoryProvider).offer(
            widget.requestId,
            me,
            message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
          );
      _messageController.clear();
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _submittingOffer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: FutureBuilder<GuestRequest>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final request = snapshot.data!;
            final isMine = request.author.id == me.id;
            final myOffer = request.offers.where((o) => o.host.id == me.id).firstOrNull;
            final canOffer = !isMine &&
                myOffer == null &&
                (request.status == RequestStatus.open || request.status == RequestStatus.offered);

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Статус: ${request.status.label}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Text('Предложения исполнителей', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (request.offers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Пока никто не откликнулся', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  else
                    ...request.offers.map((offer) {
                      final busy = _busyOfferId == offer.id;
                      final isMyOffer = offer.host.id == me.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            UserAvatar(url: offer.host.avatarUrl, size: 44, name: offer.host.name),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(offer.host.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (offer.message != null)
                                    Text(
                                      offer.message!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  const SizedBox(height: 2),
                                  RatingBadge(score: offer.host.rating, compact: true),
                                ],
                              ),
                            ),
                            if (busy)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else if (isMine && offer.status == OfferStatus.pending)
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: AppColors.success),
                                    onPressed: () => _respond(offer.id, OfferStatus.accepted),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: AppColors.danger),
                                    onPressed: () => _respond(offer.id, OfferStatus.declined),
                                  ),
                                ],
                              )
                            else if (isMyOffer && offer.status == OfferStatus.pending)
                              TextButton(
                                onPressed: () => _withdraw(offer.id),
                                child: const Text('Отозвать'),
                              )
                            else
                              Text(
                                offer.status.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: offer.status == OfferStatus.accepted
                                      ? AppColors.success
                                      : AppColors.textTertiary,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  if (canOffer) ...[
                    const Divider(height: 32),
                    const Text('Откликнуться на запрос', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Сообщение (необязательно)'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _submittingOffer ? null : _submitOffer,
                      child: _submittingOffer
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                            )
                          : const Text('Откликнуться'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
