import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../providers/city_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/pulse_sheet.dart';
import '../../data/models/city.dart';
import '../../features/events/events_providers.dart';

Future<void> showCityPickerSheet(BuildContext context, WidgetRef ref) async {
  await showPulseSheet<void>(
    context: context,
    heightFactor: 0.78,
    builder: (ctx) => const _CityPickerBody(),
  );
}

/// Compact title control: «Афиша · Минск ▾»
class AfishaCityTitle extends ConsumerWidget {
  const AfishaCityTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(selectedCityOrDefaultProvider);
    return InkWell(
      onTap: () => showCityPickerSheet(context, ref),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Афиша · ${city.name}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              PhosphorIconsRegular.caretDown,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class CityChipButton extends ConsumerWidget {
  const CityChipButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(selectedCityOrDefaultProvider);
    return ActionChip(
      avatar: Icon(PhosphorIconsRegular.mapPin, size: 16, color: AppColors.primaryLight),
      label: Text(city.name),
      onPressed: () => showCityPickerSheet(context, ref),
      backgroundColor: AppColors.surfaceAlt,
      side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    );
  }
}

class _CityPickerBody extends ConsumerStatefulWidget {
  const _CityPickerBody();

  @override
  ConsumerState<_CityPickerBody> createState() => _CityPickerBodyState();
}

class _CityPickerBodyState extends ConsumerState<_CityPickerBody> {
  final _query = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(citiesListProvider);
    final selected = ref.watch(selectedCityOrDefaultProvider);

    return PulseSheetScaffold(
      title: 'Город',
      trailing: const PulseSheetCloseButton(),
      child: citiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (cities) {
          final q = _filter.trim().toLowerCase();
          final filtered = q.isEmpty
              ? cities
              : cities
                  .where(
                    (c) =>
                        c.name.toLowerCase().contains(q) ||
                        c.slug.contains(q),
                  )
                  .toList();
          final by = filtered.where((c) => c.country == 'BY').toList();
          final ru = filtered.where((c) => c.country == 'RU').toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _query,
                  onChanged: (v) => setState(() => _filter = v),
                  decoration: const InputDecoration(
                    hintText: 'Поиск города',
                    prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (by.isNotEmpty) ...[
                      const _SectionLabel('Беларусь'),
                      ...by.map((c) => _CityTile(
                            city: c,
                            selected: c.slug == selected.slug,
                            onTap: () => _pick(c),
                          )),
                    ],
                    if (ru.isNotEmpty) ...[
                      const _SectionLabel('Россия'),
                      ...ru.map((c) => _CityTile(
                            city: c,
                            selected: c.slug == selected.slug,
                            onTap: () => _pick(c),
                          )),
                    ],
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Ничего не найдено', textAlign: TextAlign.center),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pick(AppCity city) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = city.name;
    await ref.read(selectedCityProvider.notifier).select(city);
    ref.invalidate(eventsProvider);
    if (mounted) Navigator.pop(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Показываем $name'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({
    required this.city,
    required this.selected,
    required this.onTap,
  });

  final AppCity city;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(city.name),
      trailing: selected
          ? const Icon(PhosphorIconsFill.checkCircle, color: AppColors.primary)
          : null,
    );
  }
}
