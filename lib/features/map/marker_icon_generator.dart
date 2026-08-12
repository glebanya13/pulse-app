import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Draws circular photo-thumbnail pins with a purple count badge,
/// entirely in-process via dart:ui so the map can hand Yandex MapKit a plain
/// bitmap. Falls back to a plain colored circle when the photo fails to load.
class MarkerIconGenerator {
  MarkerIconGenerator._();

  static final _cache = <String, Uint8List>{};

  static const _badgePurple = Color(0xFF7B35D6);

  static Future<Uint8List> photoPin({
    required String? imageUrl,
    required int count,
    required bool isTakeaway,
  }) async {
    // Bump key version when pin/badge visual changes so old bitmaps are dropped.
    final key = 'v3-$imageUrl-$count-$isTakeaway';
    final cached = _cache[key];
    if (cached != null) return cached;

    const double size = 168;
    const double photoDiameter = 128;
    final center = const Offset(size / 2, size / 2);

    ui.Image? photo;
    if (imageUrl != null) {
      try {
        final file = await DefaultCacheManager().getSingleFile(imageUrl);
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: photoDiameter.toInt(),
          targetHeight: photoDiameter.toInt(),
        );
        final frame = await codec.getNextFrame();
        photo = frame.image;
      } catch (_) {
        // Falls through to the plain-circle fallback below.
      }
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    if (photo != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: photoDiameter / 2)));
      paintImage(
        canvas: canvas,
        rect: Rect.fromCircle(center: center, radius: photoDiameter / 2),
        image: photo,
        fit: BoxFit.cover,
      );
      canvas.restore();
      canvas.drawCircle(
        center,
        photoDiameter / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white
          ..strokeWidth = 5,
      );
    } else {
      canvas.drawCircle(
        center,
        photoDiameter / 2,
        Paint()..color = isTakeaway ? const Color(0xFF111111) : _badgePurple,
      );
      canvas.drawCircle(
        center,
        photoDiameter / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white
          ..strokeWidth = 5,
      );
    }

    // Larger purple count badge (top-right).
    final badgeCenter = Offset(size - 28, 28);
    const badgeOuter = 26.0;
    const badgeInner = 21.0;
    canvas.drawCircle(badgeCenter, badgeOuter, Paint()..color = Colors.white);
    canvas.drawCircle(badgeCenter, badgeInner, Paint()..color = _badgePurple);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(badgeCenter.dx - textPainter.width / 2, badgeCenter.dy - textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    _cache[key] = bytes;
    return bytes;
  }

  /// Blue «я здесь» pin for my-location on the map.
  static Future<Uint8List> mePin() async {
    const key = 'me-pin-v1';
    final cached = _cache[key];
    if (cached != null) return cached;

    const double size = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    final center = const Offset(size / 2, size / 2 - 6);

    // Soft shadow
    canvas.drawCircle(
      center.translate(0, 2),
      22,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    // White ring
    canvas.drawCircle(center, 22, Paint()..color = Colors.white);
    // Blue core
    canvas.drawCircle(center, 15, Paint()..color = const Color(0xFF1E88E5));
    // Tip / pointer
    final tip = Path()
      ..moveTo(center.dx - 10, center.dy + 12)
      ..lineTo(center.dx, center.dy + 28)
      ..lineTo(center.dx + 10, center.dy + 12)
      ..close();
    canvas.drawPath(tip, Paint()..color = const Color(0xFF1E88E5));
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    _cache[key] = bytes;
    return bytes;
  }

  /// Red pin for a place picked from map search (club / address).
  static Future<Uint8List> searchPin() async {
    const key = 'search-pin-v2';
    final cached = _cache[key];
    if (cached != null) return cached;

    const double size = 160;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    final center = const Offset(size / 2, size / 2 - 10);
    const red = Color(0xFFD2201E);

    canvas.drawCircle(
      center.translate(0, 3),
      34,
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );
    canvas.drawCircle(center, 34, Paint()..color = Colors.white);
    canvas.drawCircle(center, 24, Paint()..color = red);
    final tip = Path()
      ..moveTo(center.dx - 16, center.dy + 18)
      ..lineTo(center.dx, center.dy + 46)
      ..lineTo(center.dx + 16, center.dy + 18)
      ..close();
    canvas.drawPath(tip, Paint()..color = red);
    canvas.drawCircle(center, 8, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    _cache[key] = bytes;
    return bytes;
  }
}
