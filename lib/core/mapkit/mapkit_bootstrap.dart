import 'package:flutter/foundation.dart';
import 'package:yandex_maps_mapkit_lite/init.dart' as mapkit_init;
import 'package:yandex_maps_mapkit_lite/mapkit_factory.dart';

import '../config/env.dart';

enum MapKitInitState { idle, loading, ready, failed }

/// Single place to init/start/stop Yandex MapKit.
/// Map screens must wait for [ensureInitialized] before creating [YandexMap].
class MapKitBootstrap {
  MapKitBootstrap._();

  static final MapKitBootstrap instance = MapKitBootstrap._();

  MapKitInitState state = MapKitInitState.idle;
  Object? lastError;
  int _startCount = 0;

  bool get isReady => state == MapKitInitState.ready;

  Future<bool> ensureInitialized() async {
    if (!Env.hasMapkitKey) return false;
    if (state == MapKitInitState.ready) return true;

    if (state == MapKitInitState.loading) {
      while (state == MapKitInitState.loading) {
        await Future.delayed(const Duration(milliseconds: 40));
      }
      return state == MapKitInitState.ready;
    }

    state = MapKitInitState.loading;
    lastError = null;
    try {
      await mapkit_init.initMapkit(
        apiKey: Env.yandexMapkitApiKey,
        locale: 'ru_RU',
      );
      state = MapKitInitState.ready;
      return true;
    } catch (e, st) {
      debugPrint('MapKit init failed: $e\n$st');
      lastError = e;
      state = MapKitInitState.failed;
      return false;
    }
  }

  void start() {
    if (!isReady) return;
    _startCount++;
    if (_startCount != 1) return;
    try {
      mapkit.onStart();
    } catch (e) {
      debugPrint('MapKit onStart failed: $e');
    }
  }

  void stop() {
    if (!isReady || _startCount == 0) return;
    _startCount--;
    if (_startCount != 0) return;
    try {
      mapkit.onStop();
    } catch (e) {
      debugPrint('MapKit onStop failed: $e');
    }
  }
}
