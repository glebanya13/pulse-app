import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/event_list_tile.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/city_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/city_picker.dart';
import '../../core/widgets/main_shell.dart';
import '../../data/models/enums.dart';
import '../../data/models/event.dart';
import '../../data/models/user.dart';
import 'event_filters_screen.dart';
import 'events_providers.dart';

enum _Tab { all, today, inPerson, takeaway, following, mine, going }

final _authorOfMonthProvider = FutureProvider<AuthorOfMonthShowcase>((ref) {
  return ref.watch(userRepositoryProvider).authorOfMonth();
});

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key, this.initialTab});

  /// Deep link: `tab=today` | `all` | `going` | …
  final String? initialTab;

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  late _Tab _tab = _tabFromQuery(widget.initialTab) ?? _Tab.today;

  static _Tab? _tabFromQuery(String? raw) {
    return switch (raw) {
      'today' => _Tab.today,
      'all' => _Tab.all,
      'live' || 'inPerson' || 'in_person' => _Tab.inPerson,
      'tickets' || 'takeaway' || 'bilety' => _Tab.takeaway,
      'following' || 'subs' => _Tab.following,
      'mine' || 'my' => _Tab.mine,
      'going' || 'idu' => _Tab.going,
      _ => null,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _selectTab(_tab);
    });
  }

  @override
  void didUpdateWidget(covariant EventsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      final next = _tabFromQuery(widget.initialTab);
      if (next != null && next != _tab) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _selectTab(next);
        });
      }
    }
  }

  void _selectTab(_Tab tab) {
    setState(() => _tab = tab);
    final notifier = ref.read(eventFiltersProvider.notifier);
    switch (tab) {
      case _Tab.all:
      case _Tab.mine:
      case _Tab.going:
        notifier.state = notifier.state.copyWith(
          clearFormat: true,
          clearDate: true,
          followingOnly: false,
          talentsOnly: false,
        );
      case _Tab.following:
        notifier.state = notifier.state.copyWith(
          clearFormat: true,
          clearDate: true,
          followingOnly: true,
          talentsOnly: false,
        );
      case _Tab.inPerson:
        notifier.state = notifier.state.copyWith(
          format: EventFormat.inPerson,
          clearDate: true,
          followingOnly: false,
          talentsOnly: false,
        );
      case _Tab.takeaway:
        notifier.state = notifier.state.copyWith(
          format: EventFormat.takeaway,
          clearDate: true,
          followingOnly: false,
          talentsOnly: false,
        );
      case _Tab.today:
        notifier.state = notifier.state.copyWith(
          clearFormat: true,
          date: DateTime.now(),
          followingOnly: false,
          talentsOnly: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeTab = _tabFromQuery(GoRouterState.of(context).uri.queryParameters['tab']);
    if (routeTab != null && routeTab != _tab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tab != routeTab) _selectTab(routeTab);
      });
    }

    final eventsAsync = ref.watch(eventsProvider);
    final signedIn = ref.watch(isSignedInProvider);
    final city = ref.watch(selectedCityOrDefaultProvider);
    final canHost = signedIn && (ref.read(authStateProvider)?.canHostEvents ?? false);
    final hostedAsync = signedIn ? ref.watch(myHostedEventsProvider) : null;
    final appsAsync = signedIn ? ref.watch(myApplicationsProvider) : null;

    return Scaffold(
      appBar: AppBar(
        title: const AfishaCityTitle(),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
            onPressed: () => showEventSearch(context, ref),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.faders),
            onPressed: () => showEventFiltersSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                _FilterTab(label: 'Всё', selected: _tab == _Tab.all, onTap: () => _selectTab(_Tab.all)),
                _FilterTab(label: 'Сегодня', selected: _tab == _Tab.today, onTap: () => _selectTab(_Tab.today)),
                _FilterTab(label: 'Живые', selected: _tab == _Tab.inPerson, onTap: () => _selectTab(_Tab.inPerson)),
                _FilterTab(label: 'Билеты', selected: _tab == _Tab.takeaway, onTap: () => _selectTab(_Tab.takeaway)),
                _FilterTab(
                  label: 'Подписки',
                  selected: _tab == _Tab.following,
                  onTap: () => _selectTab(_Tab.following),
                ),
                _FilterTab(label: 'Мои', selected: _tab == _Tab.mine, onTap: () => _selectTab(_Tab.mine)),
                _FilterTab(label: 'Иду', selected: _tab == _Tab.going, onTap: () => _selectTab(_Tab.going)),
              ],
            ),
          ),
          if (_tab == _Tab.all) const _AuthorOfMonthBanner(),
          Expanded(
            child: switch (_tab) {
              _Tab.mine => !signedIn
                  ? const EmptyState(
                      icon: Icons.login,
                      title: 'Войдите в аккаунт',
                      subtitle: 'Чтобы видеть свои события',
                    )
                  : hostedAsync!.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorState.fromError(
                    e,
                    onRetry: () => ref.invalidate(myHostedEventsProvider),
                  ),
                  data: (events) => _EventsListBody(
                    events: events,
                    emptyIcon: PhosphorIconsRegular.calendarPlus,
                    emptyTitle: 'Пока нет своих событий',
                    emptySubtitle: canHost
                        ? 'Опубликуйте вечер в афише ${city.name}'
                        : 'Станьте организатором в профиле, чтобы публиковать',
                    emptyActionLabel: canHost ? 'Создать событие' : null,
                    onEmptyAction: canHost ? () => context.push('/events/create') : null,
                    onRefresh: () => ref.refresh(myHostedEventsProvider.future),
                  ),
                ),
              _Tab.going => !signedIn
                  ? const EmptyState(
                      icon: Icons.login,
                      title: 'Войдите в аккаунт',
                      subtitle: 'Чтобы видеть события, куда вы идёте',
                    )
                  : appsAsync!.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorState.fromError(
                    e,
                    onRetry: () => ref.invalidate(myApplicationsProvider),
                  ),
                  data: (apps) {
                    final events = apps
                        .where((a) =>
                            a.status == ApplicationStatus.pending ||
                            a.status == ApplicationStatus.accepted)
                        .map((a) => a.event)
                        .toList();
                    return _EventsListBody(
                      events: events,
                      emptyTitle: 'Пока нет заявок',
                      emptySubtitle: 'Откликнитесь на событие - оно появится здесь',
                      onRefresh: () => ref.refresh(myApplicationsProvider.future),
                    );
                  },
                ),
              _Tab.following => !signedIn
                  ? const EmptyState(
                      icon: Icons.login,
                      title: 'Войдите в аккаунт',
                      subtitle: 'Чтобы видеть события от тех, на кого подписаны',
                    )
                  : eventsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ErrorState.fromError(
                        e,
                        onRetry: () => ref.invalidate(eventsProvider),
                      ),
                      data: (events) => _EventsListBody(
                        events: events,
                        emptyTitle: 'Пока тихо в подписках',
                        emptySubtitle: 'Подпишитесь на организаторов - их события появятся здесь',
                        onRefresh: () => ref.refresh(eventsProvider.future),
                      ),
                    ),
              _Tab.today => eventsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorState.fromError(
                    e,
                    onRetry: () => ref.invalidate(eventsProvider),
                  ),
                  data: (events) => _EventsListBody(
                    events: events,
                    emptyIcon: PhosphorIconsRegular.moonStars,
                    emptyTitle: 'Сегодня в ${city.name} тихо',
                    emptySubtitle: canHost
                        ? 'Создайте событие и станьте первыми в афише'
                        : 'Посмотрите всё расписание или загляните завтра',
                    emptyActionLabel: canHost ? 'Создать событие' : 'Смотреть всё',
                    onEmptyAction: canHost
                        ? () => context.push('/events/create')
                        : () => _selectTab(_Tab.all),
                    onRefresh: () => ref.refresh(eventsProvider.future),
                  ),
                ),
              _ => eventsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorState.fromError(
                    e,
                    onRetry: () => ref.invalidate(eventsProvider),
                  ),
                  data: (events) => _EventsListBody(
                    events: events,
                    emptyIcon: PhosphorIconsRegular.mapPin,
                    emptyTitle: 'Пока тихо в ${city.name}',
                    emptySubtitle: canHost
                        ? 'Создайте событие и станьте первыми в афише'
                        : 'Попробуйте другой город или загляните позже',
                    emptyActionLabel: canHost ? 'Создать событие' : 'Сменить город',
                    onEmptyAction: canHost
                        ? () => context.push('/events/create')
                        : () => showCityPickerSheet(context, ref),
                    onRefresh: () => ref.refresh(eventsProvider.future),
                  ),
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _EventsListBody extends StatelessWidget {
  const _EventsListBody({
    required this.events,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
    this.emptyIcon = PhosphorIconsRegular.calendarBlank,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final List<Event> events;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function() onRefresh;
  final IconData emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 100),
            EmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              subtitle: emptySubtitle,
            ),
            if (emptyActionLabel != null && onEmptyAction != null) ...[
              const SizedBox(height: 20),
              Center(
                child: FilledButton(
                  onPressed: onEmptyAction,
                  child: Text(emptyActionLabel!),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4 + kFloatingNavClearance),
        itemCount: events.length,
        separatorBuilder: (context, i) => const Divider(height: 1),
        itemBuilder: (context, i) => EventListTile(
          event: events[i],
          onTap: () => context.push('/events/${events[i].id}'),
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.highlight : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthorOfMonthBanner extends ConsumerWidget {
  const _AuthorOfMonthBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_authorOfMonthProvider);
    return async.maybeWhen(
      data: (showcase) {
        final author = showcase.author;
        if (author == null) return const SizedBox.shrink();
        final label = showcase.periodLabel.isEmpty
            ? 'Организатор месяца'
            : 'Организатор месяца · ${showcase.periodLabel}';
        return Material(
          color: AppColors.surface,
          child: InkWell(
            onTap: () => context.push('/users/${author.id}'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  UserAvatar(url: author.avatarUrl, size: 36, name: author.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class EventSearchDelegate extends SearchDelegate<void> {
  EventSearchDelegate(this.ref);

  final WidgetRef ref;

  @override
  String get searchFieldLabel => 'Концерт, клуб или район';

  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _SearchBody(query: query, ref: ref, onOpen: _open);

  @override
  Widget buildSuggestions(BuildContext context) => _SearchBody(query: query, ref: ref, onOpen: _open);

  void _open(BuildContext context, Event event) {
    close(context, null);
    context.push('/events/${event.id}');
  }
}

void showEventSearch(BuildContext context, WidgetRef ref) {
  showSearch(context: context, delegate: EventSearchDelegate(ref));
}

class _SearchBody extends ConsumerStatefulWidget {
  const _SearchBody({required this.query, required this.ref, required this.onOpen});

  final String query;
  final WidgetRef ref;
  final void Function(BuildContext context, Event event) onOpen;

  @override
  ConsumerState<_SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends ConsumerState<_SearchBody> {
  Future<List<Event>>? _future;
  Timer? _debounce;
  String _debouncedQuery = '';

  @override
  void initState() {
    super.initState();
    _schedule(widget.query);
  }

  @override
  void didUpdateWidget(covariant _SearchBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _schedule(widget.query);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule(String q) {
    _debounce?.cancel();
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _debouncedQuery = '';
        _future = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _debouncedQuery = trimmed;
        _future = _load(trimmed);
      });
    });
  }

  Future<List<Event>> _load(String q) {
    final base = widget.ref.read(eventFiltersProvider);
    final city = widget.ref.read(selectedCityOrDefaultProvider);
    return widget.ref.read(eventRepositoryProvider).list(
          filters: base.copyWith(search: q, citySlug: city.slug),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Поиск событий',
        subtitle: 'Введите название или адрес',
      );
    }
    final future = _future;
    if (future == null || _debouncedQuery != widget.query.trim()) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<List<Event>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorState(
            message: '${snap.error}',
            onRetry: () => setState(() => _future = _load(widget.query.trim())),
          );
        }
        final events = snap.data ?? [];
        if (events.isEmpty) {
          return const EmptyState(icon: Icons.search_off, title: 'Ничего не найдено');
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: events.length,
          separatorBuilder: (context, i) => const Divider(height: 1),
          itemBuilder: (context, i) => EventListTile(
            event: events[i],
            onTap: () => widget.onOpen(context, events[i]),
          ),
        );
      },
    );
  }
}
