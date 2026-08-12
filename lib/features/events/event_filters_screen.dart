import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pulse_sheet.dart';
import '../../data/models/enums.dart';
import '../../data/models/event_stickers.dart';
import '../../data/repositories/event_repository.dart';
import 'events_providers.dart';

const _sceneTags = [
  ...EventStickers.all,
  'Концерт',
  'Вечеринка',
  'Клуб',
  'Open-air',
  'DJ',
  'Stand-up',
  'Фестиваль',
];

/// Half-screen filters sheet from map / afisha.
Future<void> showEventFiltersSheet(BuildContext context) {
  return showPulseSheet<void>(
    context: context,
    heightFactor: 0.55,
    builder: (ctx) => const EventFiltersScreen(asSheet: true),
  );
}

class EventFiltersScreen extends ConsumerStatefulWidget {
  const EventFiltersScreen({super.key, this.asSheet = false});

  final bool asSheet;

  @override
  ConsumerState<EventFiltersScreen> createState() => _EventFiltersScreenState();
}

class _EventFiltersScreenState extends ConsumerState<EventFiltersScreen> {
  late EventFilters _filters = ref.read(eventFiltersProvider);
  int? _count;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final events = await ref.read(eventRepositoryProvider).list(filters: _filters);
    if (mounted) setState(() => _count = events.length);
  }

  void _update(EventFilters Function(EventFilters) fn) {
    setState(() => _filters = fn(_filters));
    _refreshCount();
  }

  void _reset() {
    setState(() => _filters = const EventFilters());
    _refreshCount();
  }

  void _apply() {
    ref.read(eventFiltersProvider.notifier).state = _filters;
    Navigator.of(context).pop();
  }

  bool _isSameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _filtersBody({required EdgeInsets padding}) {
    return ListView(
      padding: padding,
      children: [
        _Block(
          title: 'Когда',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                label: 'Сегодня',
                selected: !_filters.hasDateRange && _isSameDay(_filters.date, DateTime.now()),
                onTap: () => _update((f) => f.copyWith(date: DateTime.now(), clearDateRange: true)),
              ),
              _Chip(
                label: 'Завтра',
                selected: !_filters.hasDateRange &&
                    _isSameDay(_filters.date, DateTime.now().add(const Duration(days: 1))),
                onTap: () => _update(
                  (f) => f.copyWith(
                    date: DateTime.now().add(const Duration(days: 1)),
                    clearDateRange: true,
                  ),
                ),
              ),
              _Chip(
                label: 'Выбрать дату',
                selected: false,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _filters.date ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    _update((f) => f.copyWith(date: date, clearDateRange: true));
                  }
                },
              ),
              _Chip(
                label: 'Выходные',
                selected: _filters.hasDateRange,
                onTap: () {
                  final now = DateTime.now();
                  final daysUntilSat = (DateTime.saturday - now.weekday + 7) % 7;
                  final sat = DateTime(now.year, now.month, now.day)
                      .add(Duration(days: daysUntilSat == 0 && now.weekday != DateTime.saturday ? 7 : daysUntilSat));
                  final sun = sat.add(const Duration(days: 1));
                  _update(
                    (f) => f.copyWith(
                      clearDate: true,
                      dateRangeStart: sat,
                      dateRangeEnd: DateTime(sun.year, sun.month, sun.day, 23, 59, 59),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        _Block(
          title: 'Формат',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                label: 'Любой',
                selected: _filters.format == null,
                onTap: () => _update((f) => f.copyWith(clearFormat: true)),
              ),
              _Chip(
                label: 'Живое',
                selected: _filters.format == EventFormat.inPerson,
                onTap: () => _update((f) => f.copyWith(format: EventFormat.inPerson)),
              ),
              _Chip(
                label: 'Билеты',
                selected: _filters.format == EventFormat.takeaway,
                onTap: () => _update((f) => f.copyWith(format: EventFormat.takeaway)),
              ),
            ],
          ),
        ),
        _Block(
          title: 'Сцена',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sceneTags.map((tag) {
              final selected = _filters.tags.contains(tag);
              return _Chip(
                label: tag,
                selected: selected,
                onTap: () => _update((f) {
                  final next = [...f.tags];
                  if (selected) {
                    next.remove(tag);
                  } else {
                    next.add(tag);
                  }
                  return f.copyWith(tags: next);
                }),
              );
            }).toList(),
          ),
        ),
        _Block(
          title: 'Вход',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                label: 'Любой',
                selected: _filters.priceType == null,
                onTap: () => _update((f) => f.copyWith(clearPriceType: true)),
              ),
              _Chip(
                label: 'Бесплатно',
                selected: _filters.priceType == PriceType.free,
                onTap: () => _update((f) => f.copyWith(priceType: PriceType.free)),
              ),
              _Chip(
                label: 'Платно',
                selected: _filters.priceType == PriceType.fixed,
                onTap: () => _update((f) => f.copyWith(priceType: PriceType.fixed)),
              ),
              _Chip(
                label: 'Донат',
                selected: _filters.priceType == PriceType.donation,
                onTap: () => _update((f) => f.copyWith(priceType: PriceType.donation)),
              ),
            ],
          ),
        ),
        _Block(
          title: 'Сортировка',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EventSort.values
                .map(
                  (s) => _Chip(
                    label: s.label,
                    selected: _filters.sort == s,
                    onTap: () => _update((f) => f.copyWith(sort: s)),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _applyBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: _apply,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.highlight,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            _count == null ? 'Показать афишу' : 'Показать $_count',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asSheet) {
      return PulseSheetScaffold(
        title: 'Фильтры',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _reset,
              child: const Text('Сбросить', style: TextStyle(color: AppColors.primaryLight)),
            ),
            const PulseSheetCloseButton(),
          ],
        ),
        bottom: _applyBar(),
        child: _filtersBody(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Фильтры афиши'),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('Сбросить', style: TextStyle(color: AppColors.primaryLight)),
          ),
        ],
      ),
      body: _filtersBody(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24)),
      bottomNavigationBar: _applyBar(),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.cool.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border.withValues(alpha: 0.8),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.highlight : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
