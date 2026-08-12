import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as yk;
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

import '../../core/config/env.dart';
import '../../core/mapkit/mapkit_bootstrap.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api/place_search.dart';
import '../../data/models/event.dart';

const _minskCenter = yk.Point(latitude: 53.9023, longitude: 27.5619);

/// Result of picking a place on the map (coordinates + human-readable name).
class PickedLocation {
  const PickedLocation({required this.point, this.address, this.placeName});

  final GeoPoint point;
  final String? address;
  /// Short venue name (org title from search), for Place upsert.
  final String? placeName;
}

/// Full-screen map to pick a place for an event / pickup location.
/// Supports tap-to-pin and text search for named places (ponds, cafes, etc.).
class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({super.key, this.initial, this.initialAddress});

  final GeoPoint? initial;
  final String? initialAddress;

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen>
    with WidgetsBindingObserver
    implements yk.MapInputListener {
  yk.MapWindow? _mapWindow;
  yk.PlacemarkMapObject? _pin;
  bool _mapReady = false;
  final _bootstrap = MapKitBootstrap.instance;
  final _search = PlaceSearch();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  late yk.Point _point = yk.Point(
    latitude: widget.initial?.latitude ?? _minskCenter.latitude,
    longitude: widget.initial?.longitude ?? _minskCenter.longitude,
  );
  String? _addressLabel = '';
  String? _placeName;
  List<PlaceHit> _hits = const [];
  bool _searching = false;
  bool _resolving = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _addressLabel = widget.initialAddress?.trim().isNotEmpty == true
        ? widget.initialAddress!.trim()
        : null;
    WidgetsBinding.instance.addObserver(this);
    _prepareMap();
  }

  Future<void> _prepareMap() async {
    if (!Env.hasMapkitKey) return;
    final ready = await _bootstrap.ensureInitialized();
    if (!mounted) return;
    setState(() => _mapReady = ready);
    if (ready) _bootstrap.start();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
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
  void onMapTap(yk.Map map, yk.Point point) {
    _searchFocus.unfocus();
    setState(() {
      _point = point;
      _hits = const [];
      _searchController.clear();
    });
    _placePin(point);
    _resolveTap(point);
  }

  @override
  void onMapLongTap(yk.Map map, yk.Point point) => onMapTap(map, point);

  void _onMapCreated(yk.MapWindow window) {
    _mapWindow = window;
    window.map
      ..zoomGesturesEnabled = true
      ..scrollGesturesEnabled = true
      ..rotateGesturesEnabled = true
      ..tiltGesturesEnabled = true
      ..fastTapEnabled = true
      ..move(yk.CameraPosition(_point, zoom: 14, azimuth: 0, tilt: 0))
      ..addInputListener(this);
    window.map.logo
      ..setAlignment(
        const yk.LogoAlignment(
          yk.LogoHorizontalAlignment.Left,
          yk.LogoVerticalAlignment.Bottom,
        ),
      )
      ..setPadding(
        const yk.LogoPadding(horizontalPadding: 12, verticalPadding: 24),
      );
    _placePin(_point);
    if (_addressLabel == null) {
      _resolveTap(_point);
    }
  }

  void _placePin(yk.Point point) {
    final window = _mapWindow;
    if (window == null) return;
    if (_pin != null) {
      window.map.mapObjects.remove(_pin!);
      _pin = null;
    }
    _pin = window.map.mapObjects.addPlacemark()..geometry = point;
  }

  Future<void> _resolveTap(yk.Point point) async {
    setState(() => _resolving = true);
    try {
      final hit = await _search.reverse(
        GeoPoint(latitude: point.latitude, longitude: point.longitude),
      );
      if (!mounted) return;
      setState(() {
        _addressLabel = hit?.fullLabel ??
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addressLabel =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      });
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _hits = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    try {
      final hits = await _search.search(
        query,
        near: GeoPoint(latitude: _point.latitude, longitude: _point.longitude),
      );
      if (!mounted || _searchController.text.trim() != query.trim()) return;
      setState(() => _hits = hits);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось найти место: $e')),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectHit(PlaceHit hit) {
    _searchFocus.unfocus();
    final point = yk.Point(
      latitude: hit.point.latitude,
      longitude: hit.point.longitude,
    );
    setState(() {
      _point = point;
      _addressLabel = hit.fullLabel;
      _placeName = hit.title.trim().isNotEmpty ? hit.title.trim() : null;
      _hits = const [];
      _searchController.text = hit.title;
    });
    _placePin(point);
    _mapWindow?.map.move(
      yk.CameraPosition(point, zoom: 15, azimuth: 0, tilt: 0),
    );
  }

  void _confirm() {
    Navigator.pop(
      context,
      PickedLocation(
        point: GeoPoint(
          latitude: _point.latitude,
          longitude: _point.longitude,
        ),
        address: _addressLabel,
        placeName: _placeName ??
            (_searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Место на карте')),
      body: !Env.hasMapkitKey
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Карта временно недоступна. Выберите место позже или укажите адрес текстом.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : !_mapReady
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    YandexMap(
                      onMapCreated: _onMapCreated,
                      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                        Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
                        Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
                      },
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 12,
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(14),
                              color: AppColors.white,
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocus,
                                textInputAction: TextInputAction.search,
                                onChanged: _onQueryChanged,
                                onSubmitted: _runSearch,
                                decoration: InputDecoration(
                                  hintText: 'Клуб, бар или адрес в Минске…',
                                  prefixIcon: const Icon(Icons.search, size: 22),
                                  suffixIcon: _searching
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        )
                                      : (_searchController.text.isEmpty
                                          ? null
                                          : IconButton(
                                              icon: const Icon(Icons.close, size: 20),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() => _hits = const []);
                                              },
                                            )),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (_hits.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                constraints: const BoxConstraints(maxHeight: 240),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x22000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: _hits.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final hit = _hits[i];
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.place_outlined,
                                        color: AppColors.primary,
                                      ),
                                      title: Text(
                                        hit.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: hit.subtitle.isEmpty
                                          ? null
                                          : Text(
                                              hit.subtitle,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                      onTap: () => _selectHit(hit),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x22000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _resolving
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Определяем адрес…',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _addressLabel ??
                                          'Нажмите на карту или найдите место сверху\n'
                                              '${_point.latitude.toStringAsFixed(5)}, '
                                              '${_point.longitude.toStringAsFixed(5)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _confirm,
                                child: const Text('Выбрать это место'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
