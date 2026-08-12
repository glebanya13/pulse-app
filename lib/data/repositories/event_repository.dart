import '../../core/config/env.dart';
import '../api/api_client.dart';
import '../mock/mock_data.dart';
import '../models/application.dart';
import '../models/enums.dart';
import '../models/event.dart';
import '../models/user.dart';

/// Client-side only - the events list is small enough (single city, MVP
/// scale) that re-ordering the already-fetched page in Dart is simpler than
/// adding a `sort` param to the backend for three orderings.
enum EventSort {
  date('По дате'),
  priceAsc('Сначала дешевле'),
  priceDesc('Сначала дороже'),
  rating('По рейтингу организатора');

  const EventSort(this.label);
  final String label;
}

class EventFilters {
  final EventFormat? format;
  final List<String> tags;
  final PriceType? priceType;
  final DateTime? date;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
  final GenderFilter? gender;

  /// Free-text search (title / description / address) - sent as `?search=`.
  final String? search;
  final EventSort sort;
  /// Host rating floor (0-100), e.g. 90 for «топ хозяева».
  final int? minHostRating;
  /// Only events from hosts the viewer follows.
  final bool followingOnly;
  /// Only events from talent hosts (authorLevel ≥ 5).
  final bool talentsOnly;
  /// Catalog city slug (GET /cities).
  final String? citySlug;

  const EventFilters({
    this.format,
    this.tags = const [],
    this.priceType,
    this.date,
    this.dateRangeStart,
    this.dateRangeEnd,
    this.gender,
    this.search,
    this.sort = EventSort.date,
    this.minHostRating,
    this.followingOnly = false,
    this.talentsOnly = false,
    this.citySlug,
  });

  EventFilters copyWith({
    EventFormat? format,
    bool clearFormat = false,
    List<String>? tags,
    PriceType? priceType,
    bool clearPriceType = false,
    DateTime? date,
    bool clearDate = false,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    bool clearDateRange = false,
    GenderFilter? gender,
    String? search,
    bool clearSearch = false,
    EventSort? sort,
    int? minHostRating,
    bool clearMinHostRating = false,
    bool? followingOnly,
    bool? talentsOnly,
    String? citySlug,
    bool clearCitySlug = false,
  }) {
    return EventFilters(
      format: clearFormat ? null : (format ?? this.format),
      tags: tags ?? this.tags,
      priceType: clearPriceType ? null : (priceType ?? this.priceType),
      date: clearDate ? null : (date ?? this.date),
      dateRangeStart: clearDateRange ? null : (dateRangeStart ?? this.dateRangeStart),
      dateRangeEnd: clearDateRange ? null : (dateRangeEnd ?? this.dateRangeEnd),
      gender: gender ?? this.gender,
      search: clearSearch ? null : (search ?? this.search),
      sort: sort ?? this.sort,
      minHostRating: clearMinHostRating ? null : (minHostRating ?? this.minHostRating),
      followingOnly: followingOnly ?? this.followingOnly,
      talentsOnly: talentsOnly ?? this.talentsOnly,
      citySlug: clearCitySlug ? null : (citySlug ?? this.citySlug),
    );
  }

  bool get hasDateRange => dateRangeStart != null && dateRangeEnd != null;

  /// Matches `QueryEventsDto` on the backend.
  Map<String, dynamic> toQueryParams() => {
        if (format != null) 'format': format!.backend,
        if (priceType != null) 'priceType': priceType!.backend,
        if (tags.isNotEmpty) 'tags': tags.join(','),
        if (search != null && search!.trim().isNotEmpty) 'search': search!.trim(),
        if (hasDateRange) 'dateFrom': dateRangeStart!.toIso8601String(),
        if (hasDateRange) 'dateTo': dateRangeEnd!.toIso8601String(),
        if (!hasDateRange && date != null)
          'dateFrom': DateTime(date!.year, date!.month, date!.day).toIso8601String(),
        if (!hasDateRange && date != null)
          'dateTo': DateTime(date!.year, date!.month, date!.day, 23, 59, 59).toIso8601String(),
        if (minHostRating != null) 'minHostRating': minHostRating,
        if (followingOnly) 'followingOnly': true,
        if (talentsOnly) 'talentsOnly': true,
        if (citySlug != null && citySlug!.isNotEmpty) 'city': citySlug,
      };
}

class EventRepository {
  EventRepository(this._api) : _events = List.of(MockData.allEvents);

  final ApiClient _api;
  final List<Event> _events;
  final List<EventApplication> _applications = List.of(MockData.applications);

  Future<List<Event>> list({EventFilters filters = const EventFilters()}) async {
    List<Event> events;
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      events = _events.where((e) {
        if (filters.format != null && e.format != filters.format) return false;
        if (filters.priceType != null && e.priceType != filters.priceType) return false;
        if (filters.gender != null &&
            filters.gender != GenderFilter.any &&
            e.requirements.gender != GenderFilter.any &&
            e.requirements.gender != filters.gender) {
          return false;
        }
        if (filters.minHostRating != null &&
            e.host.rating < filters.minHostRating!) {
          return false;
        }
        if (filters.date != null) {
          final d = filters.date!;
          final dayStart = DateTime(d.year, d.month, d.day);
          final dayEnd = dayStart.add(const Duration(days: 1));
          // Window overlaps the selected calendar day.
          if (e.windowEnd.isBefore(dayStart) || !e.startAt.isBefore(dayEnd)) {
            return false;
          }
        }
        if (filters.hasDateRange) {
          final rangeStart = filters.dateRangeStart!;
          final rangeEnd = filters.dateRangeEnd!;
          if (e.windowEnd.isBefore(rangeStart) || e.startAt.isAfter(rangeEnd)) {
            return false;
          }
        }
        if (filters.search != null && filters.search!.trim().isNotEmpty) {
          final q = filters.search!.trim().toLowerCase();
          final hay = '${e.title} ${e.description} ${e.address}'.toLowerCase();
          if (!hay.contains(q)) return false;
        }
        if (filters.talentsOnly && !e.host.isTalentAuthor) return false;
        return true;
      }).toList();
    } else {
      final res = await _api.dio.get('/events', queryParameters: filters.toQueryParams());
      final items = (res.data as Map<String, dynamic>)['items'] as List;
      events = items.cast<Map<String, dynamic>>().map((e) => Event.fromJson(e)).toList();
      if (filters.gender != null && filters.gender != GenderFilter.any) {
        events = events
            .where((e) => e.requirements.gender == GenderFilter.any || e.requirements.gender == filters.gender)
            .toList();
      }
    }
    // Applied client-side regardless of data source: the backend's `category`
    // query param only accepts a single tag, so a multi-select "особенности"
    // facet (any selected tag present) has to be finished off here.
    if (filters.tags.isNotEmpty) {
      events = events.where((e) {
        return filters.tags.any((t) => e.tags.contains(t));
      }).toList();
    }
    switch (filters.sort) {
      case EventSort.date:
        // Keep paid boosts above same-day peers; preserve relative order among boosted.
        events.sort((a, b) {
          final ab = a.isActivelyBoosted;
          final bb = b.isActivelyBoosted;
          if (ab != bb) return ab ? -1 : 1;
          return a.startAt.compareTo(b.startAt);
        });
      case EventSort.priceAsc:
        events.sort((a, b) => (a.priceAmount ?? 0).compareTo(b.priceAmount ?? 0));
      case EventSort.priceDesc:
        events.sort((a, b) => (b.priceAmount ?? 0).compareTo(a.priceAmount ?? 0));
      case EventSort.rating:
        events.sort((a, b) => b.host.rating.compareTo(a.host.rating));
    }
    return events;
  }

  Future<Event> byId(String id) async {
    if (Env.useMockData) {
      return _events.firstWhere((e) => e.id == id);
    }
    final res = await _api.dio.get('/events/$id');
    return Event.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Event>> mine(String hostId) async {
    if (Env.useMockData) return List.of(MockData.myEvents);
    final res = await _api.dio.get('/users/me/events');
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map((e) => Event.fromJson(e)).toList();
  }

  Future<Event> create(Event event) async {
    if (Env.useMockData) {
      _events.insert(0, event);
      return event;
    }
    final res = await _api.dio.post('/events', data: event.toCreateJson());
    return Event.fromJson(res.data as Map<String, dynamic>, fallbackHost: event.host);
  }

  Future<Event> update(String id, Event event) async {
    if (Env.useMockData) {
      final idx = _events.indexWhere((e) => e.id == id);
      if (idx != -1) _events[idx] = event;
      return event;
    }
    final res = await _api.dio.patch('/events/$id', data: event.toCreateJson());
    return Event.fromJson(res.data as Map<String, dynamic>, fallbackHost: event.host);
  }

  Future<Event> cancel(String id, {AppUser? host}) async {
    if (Env.useMockData) {
      final idx = _events.indexWhere((e) => e.id == id);
      if (idx != -1) {
        _events[idx] = _events[idx].copyWith(status: EventStatus.cancelled);
        return _events[idx];
      }
      throw StateError('Event not found');
    }
    final res = await _api.dio.post('/events/$id/cancel');
    return Event.fromJson(res.data as Map<String, dynamic>, fallbackHost: host);
  }

  Future<void> delete(String id) async {
    if (Env.useMockData) {
      _events.removeWhere((e) => e.id == id);
      return;
    }
    await _api.dio.delete('/events/$id');
  }

  Future<List<EventApplication>> applicationsFor(String eventId) async {
    if (Env.useMockData) {
      return _applications.where((a) => a.event.id == eventId).toList();
    }
    final event = await byId(eventId);
    final res = await _api.dio.get('/events/$eventId/applications');
    return (res.data as List)
        .cast<Map<String, dynamic>>()
        .map((a) => EventApplication.fromJson(a, fallbackEvent: event))
        .toList();
  }

  Future<List<EventApplication>> myApplications(String userId, {AppUser? me}) async {
    if (Env.useMockData) {
      return _applications.where((a) => a.applicant.id == userId).toList();
    }
    final res = await _api.dio.get('/users/me/applications');
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items
        .cast<Map<String, dynamic>>()
        .map((a) => EventApplication.fromJson(a, fallbackApplicant: me))
        .toList();
  }

  Future<List<EventApplication>> hostedPendingApplications() async {
    if (Env.useMockData) {
      return _applications
          .where((a) => a.status == ApplicationStatus.pending)
          .toList();
    }
    final res = await _api.dio.get('/users/me/hosted-applications');
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map(EventApplication.fromJson).toList();
  }

  Future<void> apply(String eventId, {String? message, PickupMethod? pickupMethod}) async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      _applications.add(EventApplication(
        id: 'a_${DateTime.now().microsecondsSinceEpoch}',
        event: _events.firstWhere((e) => e.id == eventId),
        applicant: MockData.me,
        message: message,
        createdAt: DateTime.now(),
      ));
      return;
    }
    await _api.dio.post('/events/$eventId/applications', data: {
      'message': ?message,
      if (pickupMethod != null) 'pickupMethod': pickupMethod.backend,
    });
  }

  Future<String?> respondToApplication(String applicationId, ApplicationStatus status) async {
    if (Env.useMockData) {
      final idx = _applications.indexWhere((a) => a.id == applicationId);
      if (idx != -1) _applications[idx] = _applications[idx].copyWith(status: status);
      return null;
    }
    final res = await _api.dio.patch('/applications/$applicationId', data: {'status': status.backend});
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data['chatId'] as String?;
    }
    return null;
  }

  Future<EventApplication> confirmAttendance(String applicationId, {AppUser? me}) async {
    if (Env.useMockData) {
      final idx = _applications.indexWhere((a) => a.id == applicationId);
      if (idx == -1) throw StateError('Application not found');
      final now = DateTime.now();
      // In mock, confirm both sides so rating is testable.
      _applications[idx] = _applications[idx].copyWith(
        guestConfirmedAt: now,
        hostConfirmedAt: now,
        clearNoShow: true,
      );
      return _applications[idx];
    }
    final res = await _api.dio.post('/applications/$applicationId/confirm-attendance');
    return EventApplication.fromJson(
      res.data as Map<String, dynamic>,
      fallbackApplicant: me,
    );
  }

  Future<EventApplication> markNoShow(String applicationId, {AppUser? me}) async {
    if (Env.useMockData) {
      final idx = _applications.indexWhere((a) => a.id == applicationId);
      if (idx == -1) throw StateError('Application not found');
      _applications[idx] = _applications[idx].copyWith(
        hostMarkedNoShowAt: DateTime.now(),
      );
      return _applications[idx];
    }
    final res = await _api.dio.post('/applications/$applicationId/mark-no-show');
    return EventApplication.fromJson(
      res.data as Map<String, dynamic>,
      fallbackApplicant: me,
    );
  }

  Future<EventApplication> clearNoShow(String applicationId, {AppUser? me}) async {
    if (Env.useMockData) {
      final idx = _applications.indexWhere((a) => a.id == applicationId);
      if (idx == -1) throw StateError('Application not found');
      _applications[idx] = _applications[idx].copyWith(clearNoShow: true);
      return _applications[idx];
    }
    final res = await _api.dio.post('/applications/$applicationId/clear-no-show');
    return EventApplication.fromJson(
      res.data as Map<String, dynamic>,
      fallbackApplicant: me,
    );
  }

  Future<List<Event>> favorites() async {
    if (Env.useMockData) {
      return _events.where((e) => e.isFavorite).toList();
    }
    final res = await _api.dio.get('/favorites');
    return (res.data as List)
        .cast<Map<String, dynamic>>()
        .map((e) => Event.fromJson(e).copyWith(isFavorite: true))
        .toList();
  }

  Future<void> setFavorite(String eventId, bool favorite) async {
    if (Env.useMockData) {
      final idx = _events.indexWhere((e) => e.id == eventId);
      if (idx != -1) _events[idx] = _events[idx].copyWith(isFavorite: favorite);
      return;
    }
    if (favorite) {
      await _api.dio.post('/favorites/$eventId');
    } else {
      await _api.dio.delete('/favorites/$eventId');
    }
  }

  Future<void> recordView(String eventId) async {
    if (Env.useMockData) return;
    try {
      await _api.dio.post('/events/$eventId/view');
    } catch (_) {
      // Impression tracking must not block UX.
    }
  }

  Future<EventStats> stats(String eventId) async {
    if (Env.useMockData) {
      final event = _events.firstWhere((e) => e.id == eventId);
      return EventStats(
        viewCount: event.viewCount,
        applicationsCount: 0,
        acceptedCount: event.currentGuests,
        isBoosted: event.isActivelyBoosted,
        boostedUntil: event.boostedUntil,
        currentGuestsCount: event.currentGuests,
      );
    }
    final res = await _api.dio.get('/events/$eventId/stats');
    return EventStats.fromJson(res.data as Map<String, dynamic>);
  }
}
