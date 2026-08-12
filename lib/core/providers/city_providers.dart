import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/repository_providers.dart';
import '../../data/models/city.dart';
import '../ritual/pulse_local_reminders.dart';
import 'auth_providers.dart';

const _prefsCitySlugKey = 'pulse_selected_city_slug';

final citiesListProvider = FutureProvider<List<AppCity>>((ref) {
  return ref.watch(citiesRepositoryProvider).list();
});

class SelectedCityNotifier extends AsyncNotifier<AppCity> {
  @override
  Future<AppCity> build() async {
    final cities = await ref.watch(citiesListProvider.future);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsCitySlugKey);
    AppCity city;
    if (saved != null) {
      final match = ref.read(citiesRepositoryProvider).bySlug(saved, cities);
      city = match ??
          ref.read(citiesRepositoryProvider).bySlug('minsk', cities) ??
          (cities.isNotEmpty ? cities.first : kDefaultCity);
    } else {
      city = ref.read(citiesRepositoryProvider).bySlug('minsk', cities) ??
          (cities.isNotEmpty ? cities.first : kDefaultCity);
    }
    await PulseLocalReminders.rescheduleForCity(city.name);
    return city;
  }

  Future<void> select(AppCity city) async {
    state = AsyncData(city);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCitySlugKey, city.slug);
    await PulseLocalReminders.rescheduleForCity(city.name);

    final me = ref.read(authStateProvider);
    if (me != null && me.city != city.name) {
      try {
        final updated = await ref.read(userRepositoryProvider).updateProfile(
              city: city.name,
            );
        ref.read(authStateProvider.notifier).updateProfile(updated);
      } catch (_) {
        // Local city still applies even if profile sync fails.
      }
    }
  }
}

final selectedCityProvider =
    AsyncNotifierProvider<SelectedCityNotifier, AppCity>(SelectedCityNotifier.new);

/// Sync helper for widgets that need a city immediately.
final selectedCityOrDefaultProvider = Provider<AppCity>((ref) {
  return ref.watch(selectedCityProvider).maybeWhen(
        data: (c) => c,
        orElse: () => kDefaultCity,
      );
});
