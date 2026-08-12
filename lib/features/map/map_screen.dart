import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show instantiateImageCodec;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:yandex_maps_mapkit_lite/image.dart' as yk_image;
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as yk;
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

import '../../core/config/env.dart';
import '../../core/providers/city_providers.dart';
import '../../core/mapkit/mapkit_bootstrap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/city_picker.dart';
import '../../core/widgets/main_shell.dart';
import '../../data/api/place_search.dart';
import '../../data/api/place_search_history.dart';
import '../../data/models/event.dart';
import '../events/events_providers.dart';
import 'map_search.dart';
import 'marker_icon_generator.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver
    implements yk.MapObjectTapListener {
  yk.MapWindow? _mapWindow;
  final List<yk.PlacemarkMapObject> _placemarks = [];
  yk.PlacemarkMapObject? _mePin;
  yk.PlacemarkMapObject? _searchPin;
  PlaceHit? _focusedPlace;
  bool _locating = false;
  bool _mapReady = false;
  bool _markersLoading = false;
  bool _markersDirty = false;
  bool _didAutoLocate = false;
  String? _mapError;
  String? _lastMarkerSignature;
  Timer? _syncDebounce;
  final _bootstrap = MapKitBootstrap.instance;
  String? _lastCitySlug;

  yk.Point get _cityCenter {
    final city = ref.read(selectedCityOrDefaultProvider);
    return yk.Point(latitude: city.lat, longitude: city.lng);
  }

  void _moveToSelectedCity() {
    final window = _mapWindow;
    if (window == null) return;
    window.map.move(yk.CameraPosition(_cityCenter, zoom: 12, azimuth: 0, tilt: 0));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepareMap();
  }

  Future<void> _prepareMap() async {
    if (!Env.hasMapkitKey) return;
    final ready = await _bootstrap.ensureInitialized();
    if (!mounted) return;
    setState(() {
      _mapReady = ready;
      if (!ready) {
        final detail = _bootstrap.lastError?.toString() ?? '';
        _mapError = detail.contains('lookup symbol') || detail.contains('yandex_maps_flutter')
            ? 'Карта недоступна в этой версии приложения. Откройте список событий.'
            : 'Карта временно недоступна. Откройте список событий.';
      }
    });
    if (ready) _bootstrap.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncDebounce?.cancel();
    _bootstrap.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_mapReady) return;
    if (state == AppLifecycleState.resumed) {
      _bootstrap.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _bootstrap.stop();
    }
  }

  @override
  bool onMapObjectTap(yk.MapObject mapObject, yk.Point point) {
    final ids = mapObject.userData;
    if (ids is List<String> && ids.isNotEmpty) {
      if (ids.length == 1) {
        context.push('/events/${ids.first}');
      } else {
        _showClusterSheet(ids);
      }
      return true;
    }
    return false;
  }

  void _onMapCreated(yk.MapWindow window) {
    _mapWindow = window;
    window.map
      ..zoomGesturesEnabled = true
      ..scrollGesturesEnabled = true
      ..rotateGesturesEnabled = true
      ..tiltGesturesEnabled = true
      ..fastTapEnabled = true;
    // Keep Yandex logo visible but out of the search chrome (ToS).
    window.map.logo
      ..setAlignment(
        const yk.LogoAlignment(
          yk.LogoHorizontalAlignment.Left,
          yk.LogoVerticalAlignment.Bottom,
        ),
      )
      ..setPadding(
        const yk.LogoPadding(horizontalPadding: 12, verticalPadding: 96),
      );
    window.map.cameraBounds
      ..setMinZoomPreference(9)
      ..setMaxZoomPreference(19);
    window.map.move(yk.CameraPosition(_cityCenter, zoom: 12, azimuth: 0, tilt: 0));
    _lastCitySlug = ref.read(selectedCityOrDefaultProvider).slug;
    _syncPlacemarks();
    if (!_didAutoLocate) {
      _didAutoLocate = true;
      // Soft: map opens on the user's real point when permission allows.
      unawaited(_goToMyLocation(silent: true));
    }
  }

  void _zoomBy(double delta) {
    final window = _mapWindow;
    if (window == null) return;
    final cam = window.map.cameraPosition;
    final next = (cam.zoom + delta).clamp(
      window.map.cameraBounds.getMinZoom(),
      window.map.cameraBounds.getMaxZoom(),
    );
    if ((next - cam.zoom).abs() < 0.01) return;
    window.map.move(
      yk.CameraPosition(cam.target, zoom: next, azimuth: cam.azimuth, tilt: cam.tilt),
    );
  }

  Future<void> _goToMyLocation({bool silent = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Включите геолокацию в настройках устройства')),
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нужен доступ к геолокации')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );
      // Keep the map on the selected city unless GPS is nearby (simulators
      // often report Cupertino / random coords).
      final city = ref.read(selectedCityOrDefaultProvider);
      if (silent && !city.containsApprox(pos.latitude, pos.longitude)) {
        return;
      }
      if (!silent && !city.containsApprox(pos.latitude, pos.longitude)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Геолокация вне ${city.name}, показываем город')),
          );
        }
        final window = _mapWindow;
        window?.map.move(yk.CameraPosition(_cityCenter, zoom: 12, azimuth: 0, tilt: 0));
        return;
      }
      final point = yk.Point(latitude: pos.latitude, longitude: pos.longitude);
      final window = _mapWindow;
      if (window == null) return;

      if (_mePin != null) {
        window.map.mapObjects.remove(_mePin!);
        _mePin = null;
      }

      final iconBytes = await MarkerIconGenerator.mePin();
      final pin = window.map.mapObjects.addPlacemark()
        ..geometry = point
        ..setIcon(yk_image.ImageProvider(() async {
          final codec = await instantiateImageCodec(iconBytes);
          final frame = await codec.getNextFrame();
          return frame.image;
        }));
      pin.setIconStyle(
        const yk.IconStyle(
          anchor: math.Point(0.5, 0.9),
          scale: 0.9,
        ),
      );
      _mePin = pin;

      // Zoom close enough that the pin is an obvious point, not just an area.
      window.map.move(yk.CameraPosition(point, zoom: 16, azimuth: 0, tilt: 0));
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось определить местоположение: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _focusPlace(PlaceHit place) async {
    final window = _mapWindow;
    if (window == null) return;
    final point = yk.Point(
      latitude: place.point.latitude,
      longitude: place.point.longitude,
    );

    if (_searchPin != null) {
      window.map.mapObjects.remove(_searchPin!);
      _searchPin = null;
    }

    final iconBytes = await MarkerIconGenerator.searchPin();
    if (!mounted || _mapWindow != window) return;

    final pin = window.map.mapObjects.addPlacemark()
      ..geometry = point
      ..setIcon(yk_image.ImageProvider(() async {
        final codec = await instantiateImageCodec(iconBytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }));
    pin.setIconStyle(
      const yk.IconStyle(
        anchor: math.Point(0.5, 0.92),
        scale: 1.25,
      ),
    );
    _searchPin = pin;

    window.map.move(yk.CameraPosition(point, zoom: 17, azimuth: 0, tilt: 0));
    unawaited(PlaceSearchHistory.add(place));
    setState(() {
      _focusedPlace = place;
    });
  }

  void _scheduleSyncPlacemarks() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) unawaited(_syncPlacemarks());
    });
  }

  Future<void> _syncPlacemarks() async {
    final window = _mapWindow;
    if (window == null) return;
    if (_markersLoading) {
      _markersDirty = true;
      return;
    }
    _markersLoading = true;
    _markersDirty = false;
    try {
      final events = await ref.read(eventsProvider.future);
      final signature = events.map((e) => '${e.id}:${e.coverPhoto ?? ''}').join('|');
      if (signature == _lastMarkerSignature && _placemarks.isNotEmpty) {
        return;
      }

      for (final p in _placemarks) {
        window.map.mapObjects.remove(p);
      }
      _placemarks.clear();

      final buckets = <String, List<Event>>{};
      for (final e in events) {
        final key =
            '${e.location.latitude.toStringAsFixed(2)}_${e.location.longitude.toStringAsFixed(2)}';
        buckets.putIfAbsent(key, () => []).add(e);
      }

      for (final bucket in buckets.values) {
        final first = bucket.first;
        final bytes = await MarkerIconGenerator.photoPin(
          imageUrl: first.coverPhoto == null ? null : Env.resolveMediaUrl(first.coverPhoto!),
          count: bucket.length,
          isTakeaway: first.isTakeaway,
        );
        if (!mounted || _mapWindow != window) return;
        final placemark = window.map.mapObjects.addPlacemark()
          ..geometry = yk.Point(
            latitude: first.location.latitude,
            longitude: first.location.longitude,
          )
          ..setIcon(yk_image.ImageProvider(() async {
            final codec = await instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            return frame.image;
          }))
          ..userData = bucket.map((e) => e.id).toList();
        placemark.setIconStyle(
          const yk.IconStyle(
            anchor: math.Point(0.5, 0.5),
            scale: 1.35,
          ),
        );
        placemark.addTapListener(this);
        _placemarks.add(placemark);
      }

      _lastMarkerSignature = signature;
      if (mounted && _mapError != null) {
        setState(() => _mapError = null);
      }
    } catch (e) {
      debugPrint('Map sync failed: $e');
      if (mounted) {
        setState(() => _mapError = 'Не удалось загрузить карту. Откройте список событий.');
      }
    } finally {
      _markersLoading = false;
      if (_markersDirty && mounted) {
        _markersDirty = false;
        unawaited(_syncPlacemarks());
      }
    }
  }

  void _showClusterSheet(List<String> eventIds) {
    final events = ref.read(eventsProvider).value ?? [];
    final matches = events.where((e) => eventIds.contains(e.id)).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: matches
              .map((e) => ListTile(
                    title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${formatEventWindow(e.startAt, e.endAt)} · ${e.address}'),
                    trailing: Text(e.priceLabel),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/events/${e.id}');
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  bool _sameEventIds(List<Event> a, List<Event> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(selectedCityOrDefaultProvider);
    ref.listen(selectedCityProvider, (prev, next) {
      final slug = next.asData?.value.slug;
      if (slug == null || slug == _lastCitySlug) return;
      _lastCitySlug = slug;
      _moveToSelectedCity();
      ref.invalidate(eventsProvider);
    });
    ref.listen(eventsProvider, (previous, next) {
      if (!next.hasValue) return;
      final prev = previous?.valueOrNull;
      final curr = next.requireValue;
      if (prev != null &&
          prev.length == curr.length &&
          identical(prev, curr)) {
        return;
      }
      if (prev != null &&
          prev.length == curr.length &&
          _sameEventIds(prev, curr)) {
        return;
      }
      _scheduleSyncPlacemarks();
    });

    return Scaffold(
      body: Stack(
        children: [
          if (_mapReady)
            RepaintBoundary(
              child: YandexMap(
                onMapCreated: _onMapCreated,
                gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
                  Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
                  Factory<ScaleGestureRecognizer>(ScaleGestureRecognizer.new),
                },
              ),
            )
          else if (!Env.hasMapkitKey)
            _MissingApiKeyPlaceholder(onOpenList: () => context.push('/home/events?tab=today'))
          else
            const ColoredBox(
              color: AppColors.surface,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_mapError != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 72, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsRegular.mapTrifold, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _mapError!,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/home/events?tab=today'),
                        child: const Text('Список'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _SearchPill(
                      cityName: city.name,
                      onCityTap: () => showCityPickerSheet(context, ref),
                      onSearchTap: () => showMapSearch(
                        context,
                        ref,
                        onPlaceSelected: _focusPlace,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AfishaChip(onTap: () => context.push('/home/events?tab=today')),
                ],
              ),
            ),
          ),
          if (_focusedPlace != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + kFloatingNavClearance,
              child: _FocusedPlaceCard(
                place: _focusedPlace!,
                onClose: () {
                  final window = _mapWindow;
                  if (_searchPin != null && window != null) {
                    window.map.mapObjects.remove(_searchPin!);
                    _searchPin = null;
                  }
                  setState(() => _focusedPlace = null);
                },
              ),
            ),
          Positioned(
            right: 16,
            bottom: _focusedPlace != null
                ? 148 + kFloatingNavClearance
                : 36 + kFloatingNavClearance,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoundIconButton(
                  icon: PhosphorIconsBold.plus,
                  onTap: () => _zoomBy(1),
                ),
                const SizedBox(height: 8),
                _RoundIconButton(
                  icon: PhosphorIconsBold.minus,
                  onTap: () => _zoomBy(-1),
                ),
                const SizedBox(height: 10),
                _RoundIconButton(
                  icon: _locating
                      ? PhosphorIconsRegular.circleNotch
                      : PhosphorIconsRegular.crosshair,
                  onTap: _locating ? () {} : () => _goToMyLocation(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({
    required this.cityName,
    required this.onCityTap,
    required this.onSearchTap,
  });

  final String cityName;
  final VoidCallback onCityTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(999),
      elevation: 4,
      shadowColor: Colors.black38,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            InkWell(
              onTap: onCityTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsRegular.mapPin,
                      size: 16,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        cityName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      PhosphorIconsRegular.caretDown,
                      size: 12,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 1, height: 22, color: AppColors.border),
            Expanded(
              child: InkWell(
                onTap: onSearchTap,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        size: 18,
                        color: Color(0xFFAEAEB2),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Клуб, адрес…',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFAEAEB2),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AfishaChip extends StatelessWidget {
  const _AfishaChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(999),
      elevation: 4,
      shadowColor: Colors.black38,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsRegular.calendarBlank, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Афиша',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black38,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: AppColors.highlight),
        ),
      ),
    );
  }
}

class _FocusedPlaceCard extends StatelessWidget {
  const _FocusedPlaceCard({required this.place, required this.onClose});

  final PlaceHit place;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black,
      borderRadius: BorderRadius.circular(20),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(PhosphorIconsFill.mapPin, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    place.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  if (place.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      place.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.x),
              onPressed: onClose,
              tooltip: 'Убрать метку',
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingApiKeyPlaceholder extends StatelessWidget {
  const _MissingApiKeyPlaceholder({required this.onOpenList});

  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIconsRegular.mapTrifold, size: 56, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              const Text(
                'Карта временно недоступна',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Пока можно смотреть события списком. Мы уже знаем о проблеме.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onOpenList, child: const Text('Открыть список событий')),
            ],
          ),
        ),
      ),
    );
  }
}
