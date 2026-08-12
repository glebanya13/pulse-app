import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/city_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/models/application.dart';
import '../../data/models/event.dart';
import '../../data/repositories/event_repository.dart';

final eventFiltersProvider = StateProvider<EventFilters>((ref) => const EventFilters());

final eventsProvider = FutureProvider<List<Event>>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  final filters = ref.watch(eventFiltersProvider);
  final city = ref.watch(selectedCityOrDefaultProvider);
  return repo.list(filters: filters.copyWith(citySlug: city.slug));
});

final eventByIdProvider = FutureProvider.family<Event, String>((ref, id) {
  return ref.watch(eventRepositoryProvider).byId(id);
});

final myHostedEventsProvider = FutureProvider<List<Event>>((ref) {
  final me = ref.watch(currentUserProvider);
  return ref.watch(eventRepositoryProvider).mine(me.id);
});

final myApplicationsProvider = FutureProvider<List<EventApplication>>((ref) {
  final me = ref.watch(currentUserProvider);
  return ref.watch(eventRepositoryProvider).myApplications(me.id, me: me);
});

/// Pending applications on events I host (inbox for the host).
final hostedPendingApplicationsProvider =
    FutureProvider<List<EventApplication>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(eventRepositoryProvider).hostedPendingApplications();
});

final eventApplicationsProvider =
    FutureProvider.family<List<EventApplication>, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).applicationsFor(eventId);
});

final myFavoritesProvider = FutureProvider<List<Event>>((ref) {
  return ref.watch(eventRepositoryProvider).favorites();
});

final eventStatsProvider = FutureProvider.family<EventStats, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).stats(eventId);
});
