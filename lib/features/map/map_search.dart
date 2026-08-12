import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/providers/city_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/event_list_tile.dart';
import '../../data/api/place_search.dart';
import '../../data/api/place_search_history.dart';
import '../../data/models/event.dart';
import '../events/events_providers.dart';

/// Map search: places (Yandex Geosuggest / geocoder) + in-app events.
void showMapSearch(
  BuildContext context,
  WidgetRef ref, {
  required void Function(PlaceHit place) onPlaceSelected,
}) {
  showSearch(
    context: context,
    delegate: _MapSearchDelegate(ref, onPlaceSelected: onPlaceSelected),
  );
}

class _MapSearchDelegate extends SearchDelegate<void> {
  _MapSearchDelegate(this.ref, {required this.onPlaceSelected});

  final WidgetRef ref;
  final void Function(PlaceHit place) onPlaceSelected;

  @override
  String get searchFieldLabel => 'Концерт, клуб или район';

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _MapSearchBody(
        query: query,
        ref: ref,
        onEvent: (event) {
          close(context, null);
          context.push('/events/${event.id}');
        },
        onPlace: (place) {
          close(context, null);
          onPlaceSelected(place);
        },
      );

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

class _MapSearchPayload {
  const _MapSearchPayload({required this.places, required this.events});

  final List<PlaceHit> places;
  final List<Event> events;

  bool get isEmpty => places.isEmpty && events.isEmpty;
}

class _MapSearchBody extends ConsumerStatefulWidget {
  const _MapSearchBody({
    required this.query,
    required this.ref,
    required this.onEvent,
    required this.onPlace,
  });

  final String query;
  final WidgetRef ref;
  final void Function(Event event) onEvent;
  final void Function(PlaceHit place) onPlace;

  @override
  ConsumerState<_MapSearchBody> createState() => _MapSearchBodyState();
}

class _MapSearchBodyState extends ConsumerState<_MapSearchBody> {
  Future<_MapSearchPayload>? _future;
  Future<List<PlaceHit>>? _historyFuture;
  Timer? _debounce;
  String _debouncedQuery = '';
  final _places = PlaceSearch();

  @override
  void initState() {
    super.initState();
    _historyFuture = PlaceSearchHistory.load();
    _schedule(widget.query);
  }

  @override
  void didUpdateWidget(covariant _MapSearchBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _schedule(widget.query);
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
        _historyFuture = PlaceSearchHistory.load();
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

  Future<GeoPoint?> _near() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return GeoPoint(latitude: last.latitude, longitude: last.longitude);
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      return GeoPoint(latitude: pos.latitude, longitude: pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<_MapSearchPayload> _load(String q) async {
    final city = widget.ref.read(selectedCityOrDefaultProvider);
    final near = (await _near()) ?? city.center;
    final base = widget.ref.read(eventFiltersProvider);
    final placesFuture = _places.search(q, near: near, limit: 8);
    final eventsFuture = widget.ref.read(eventRepositoryProvider).list(
          filters: base.copyWith(search: q, citySlug: city.slug),
        );
    final results = await Future.wait([placesFuture, eventsFuture]);
    return _MapSearchPayload(
      places: results[0] as List<PlaceHit>,
      events: results[1] as List<Event>,
    );
  }

  Future<void> _clearHistory() async {
    await PlaceSearchHistory.clear();
    if (!mounted) return;
    setState(() => _historyFuture = PlaceSearchHistory.load());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isEmpty) {
      return FutureBuilder<List<PlaceHit>>(
        future: _historyFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final history = snap.data ?? const <PlaceHit>[];
          if (history.isEmpty) {
            return const EmptyState(
              icon: Icons.search,
              title: 'Поиск на карте',
              subtitle: 'Концерт, клуб или район в Минске',
            );
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Недавние',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearHistory,
                      child: const Text('Очистить'),
                    ),
                  ],
                ),
              ),
              ...history.map(
                (p) => ListTile(
                  leading: const Icon(Icons.history, color: AppColors.textSecondary),
                  title: Text(p.title),
                  subtitle: p.subtitle.isEmpty ? null : Text(p.subtitle),
                  onTap: () => widget.onPlace(p),
                ),
              ),
            ],
          );
        },
      );
    }
    final future = _future;
    if (future == null || _debouncedQuery != widget.query.trim()) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<_MapSearchPayload>(
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
        final data = snap.data ?? const _MapSearchPayload(places: [], events: []);
        if (data.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off,
            title: 'Ничего не найдено',
            subtitle: 'Попробуйте другое название клуба или адреса',
          );
        }

        return ListView(
          children: [
            if (data.places.isNotEmpty) ...[
              const _SectionHeader('Места'),
              ...data.places.map(
                (p) => ListTile(
                  leading: const Icon(Icons.place_outlined, color: AppColors.primary),
                  title: Text(p.title),
                  subtitle: p.subtitle.isEmpty ? null : Text(p.subtitle),
                  onTap: () => widget.onPlace(p),
                ),
              ),
            ],
            if (data.events.isNotEmpty) ...[
              const _SectionHeader('События'),
              ...data.events.map(
                (e) => EventListTile(
                  event: e,
                  onTap: () => widget.onEvent(e),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
