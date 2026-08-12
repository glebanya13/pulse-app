import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';

enum StoryFilter {
  none,
  clarendon,
  moon,
  pulse,
  mono,
  warm,
}

enum StoryEffect {
  none,
  vignette,
  haze,
  grain,
}

enum StoryLayout {
  fill,
  fit,
  mirror,
}

extension StoryFilterX on StoryFilter {
  String get label => switch (this) {
        StoryFilter.none => 'Оригинал',
        StoryFilter.clarendon => 'Яркий',
        StoryFilter.moon => 'Луна',
        StoryFilter.pulse => 'Пульс',
        StoryFilter.mono => 'Ч/Б',
        StoryFilter.warm => 'Тёплый',
      };

  ColorFilter? get colorFilter {
    switch (this) {
      case StoryFilter.none:
        return null;
      case StoryFilter.clarendon:
        return const ColorFilter.matrix(<double>[
          1.2, -0.05, -0.05, 0, 10,
          -0.05, 1.15, -0.05, 0, 10,
          -0.05, -0.05, 1.25, 0, 15,
          0, 0, 0, 1, 0,
        ]);
      case StoryFilter.moon:
        return const ColorFilter.matrix(<double>[
          0.9, 0.05, 0.15, 0, -10,
          0.05, 0.85, 0.2, 0, -5,
          0.15, 0.1, 1.1, 0, 20,
          0, 0, 0, 1, 0,
        ]);
      case StoryFilter.pulse:
        return const ColorFilter.matrix(<double>[
          1.05, 0.05, 0.2, 0, 8,
          0.05, 0.9, 0.15, 0, 0,
          0.15, 0.05, 1.25, 0, 25,
          0, 0, 0, 1, 0,
        ]);
      case StoryFilter.mono:
        return const ColorFilter.matrix(<double>[
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case StoryFilter.warm:
        return const ColorFilter.matrix(<double>[
          1.2, 0.1, 0, 0, 15,
          0.05, 1.05, 0, 0, 5,
          0, 0, 0.85, 0, -10,
          0, 0, 0, 1, 0,
        ]);
    }
  }
}

extension StoryEffectX on StoryEffect {
  String get label => switch (this) {
        StoryEffect.none => 'Без эффекта',
        StoryEffect.vignette => 'Виньетка',
        StoryEffect.haze => 'Дымка',
        StoryEffect.grain => 'Зерно',
      };
}

extension StoryLayoutX on StoryLayout {
  String get label => switch (this) {
        StoryLayout.fill => 'Заполнение',
        StoryLayout.fit => 'Вписать',
        StoryLayout.mirror => 'Зеркало',
      };
}

/// Bake filter / layout / text into a story-ready image.
Future<File> composeStoryImage({
  required File source,
  StoryFilter filter = StoryFilter.none,
  StoryEffect effect = StoryEffect.none,
  StoryLayout layout = StoryLayout.fill,
  String text = '',
}) async {
  final bytes = await source.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1080);
  final frame = await codec.getNextFrame();
  final src = frame.image;

  const outW = 1080.0;
  const outH = 1920.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outW, outH));

  canvas.drawRect(
    Rect.fromLTWH(0, 0, outW, outH),
    Paint()..color = const Color(0xFF0A0A0B),
  );

  final paint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high;
  final cf = filter.colorFilter;
  if (cf != null) paint.colorFilter = cf;

  final srcW = src.width.toDouble();
  final srcH = src.height.toDouble();

  void drawCover(Rect dst) {
    final scale = math.max(dst.width / srcW, dst.height / srcH);
    final w = srcW * scale;
    final h = srcH * scale;
    final left = dst.left + (dst.width - w) / 2;
    final top = dst.top + (dst.height - h) / 2;
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, srcW, srcH),
      Rect.fromLTWH(left, top, w, h),
      paint,
    );
  }

  void drawContain(Rect dst) {
    final scale = math.min(dst.width / srcW, dst.height / srcH);
    final w = srcW * scale;
    final h = srcH * scale;
    final left = dst.left + (dst.width - w) / 2;
    final top = dst.top + (dst.height - h) / 2;
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, srcW, srcH),
      Rect.fromLTWH(left, top, w, h),
      paint,
    );
  }

  switch (layout) {
    case StoryLayout.fill:
      drawCover(Rect.fromLTWH(0, 0, outW, outH));
    case StoryLayout.fit:
      drawContain(Rect.fromLTWH(0, 0, outW, outH));
    case StoryLayout.mirror:
      drawCover(const Rect.fromLTWH(0, 0, outW / 2, outH));
      canvas.save();
      canvas.translate(outW, 0);
      canvas.scale(-1, 1);
      drawCover(const Rect.fromLTWH(0, 0, outW / 2, outH));
      canvas.restore();
  }

  switch (effect) {
    case StoryEffect.none:
      break;
    case StoryEffect.vignette:
      final vignette = Paint()
        ..shader = ui.Gradient.radial(
          const Offset(outW / 2, outH / 2),
          outH * 0.72,
          const [
            Color(0x00000000),
            Color(0x99000000),
          ],
          const [0.45, 1.0],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, outW, outH), vignette);
    case StoryEffect.haze:
      canvas.drawRect(
        Rect.fromLTWH(0, 0, outW, outH),
        Paint()..color = AppColors.primary.withValues(alpha: 0.22),
      );
    case StoryEffect.grain:
      final rnd = math.Random(7);
      final grain = Paint()..color = const Color(0x22FFFFFF);
      for (var i = 0; i < 1200; i++) {
        canvas.drawCircle(
          Offset(rnd.nextDouble() * outW, rnd.nextDouble() * outH),
          rnd.nextDouble() * 1.4,
          grain,
        );
      }
  }

  final trimmed = text.trim();
  if (trimmed.isNotEmpty) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        maxLines: 6,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: const Color(0xFFF7F7F8),
          fontSize: 52,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      )
      ..addText(trimmed);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: outW - 120));
    final bg = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(outW / 2, outH * 0.72),
        width: paragraph.width + 48,
        height: paragraph.height + 28,
      ),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      bg,
      Paint()..color = const Color(0xCC141416),
    );
    canvas.drawParagraph(
      paragraph,
      Offset((outW - paragraph.width) / 2, outH * 0.72 - paragraph.height / 2),
    );
  }

  final picture = recorder.endRecording();
  final outImage = await picture.toImage(outW.toInt(), outH.toInt());
  final data = await outImage.toByteData(format: ui.ImageByteFormat.png);
  src.dispose();
  outImage.dispose();
  if (data == null) return source;

  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/pulse_story_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(data.buffer.asUint8List());
  return file;
}

/// Bake a 1:1 post frame matching the create-screen preview.
/// [coverCrop] true → BoxFit.cover; false → BoxFit.contain on black.
Future<File> composeSquarePostImage({
  required File source,
  bool coverCrop = true,
  int size = 1080,
}) async {
  final bytes = await source.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: size * 2);
  final frame = await codec.getNextFrame();
  final src = frame.image;

  final out = size.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, out, out));
  canvas.drawRect(
    Rect.fromLTWH(0, 0, out, out),
    Paint()..color = const Color(0xFF000000),
  );

  final paint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high;
  final srcW = src.width.toDouble();
  final srcH = src.height.toDouble();
  final dst = Rect.fromLTWH(0, 0, out, out);

  if (coverCrop) {
    final scale = math.max(dst.width / srcW, dst.height / srcH);
    final w = srcW * scale;
    final h = srcH * scale;
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, srcW, srcH),
      Rect.fromLTWH((dst.width - w) / 2, (dst.height - h) / 2, w, h),
      paint,
    );
  } else {
    final scale = math.min(dst.width / srcW, dst.height / srcH);
    final w = srcW * scale;
    final h = srcH * scale;
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, srcW, srcH),
      Rect.fromLTWH((dst.width - w) / 2, (dst.height - h) / 2, w, h),
      paint,
    );
  }

  final picture = recorder.endRecording();
  final outImage = await picture.toImage(size, size);
  final data = await outImage.toByteData(format: ui.ImageByteFormat.png);
  src.dispose();
  outImage.dispose();
  if (data == null) return source;

  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/pulse_post_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(data.buffer.asUint8List());
  return file;
}

/// Forward + reverse frames as an animated GIF (boomerang).
Future<File> encodeBoomerangGif(
  List<File> frames, {
  int delayCs = 8,
  int maxWidth = 480,
}) async {
  if (frames.isEmpty) {
    throw StateError('encodeBoomerangGif: no frames');
  }
  final sequence = <File>[
    ...frames,
    ...frames.reversed.skip(1),
  ];
  final encoder = img.GifEncoder(repeat: 0, delay: delayCs);
  for (final frameFile in sequence) {
    final bytes = await frameFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) continue;
    final framed = decoded.width > maxWidth
        ? img.copyResize(decoded, width: maxWidth)
        : decoded;
    encoder.addFrame(framed, duration: delayCs);
  }
  final gifBytes = encoder.finish();
  if (gifBytes == null || gifBytes.isEmpty) {
    throw StateError('encodeBoomerangGif: encoder produced empty output');
  }
  final dir = await getTemporaryDirectory();
  final out = File(
    '${dir.path}/pulse_boomerang_${DateTime.now().millisecondsSinceEpoch}.gif',
  );
  await out.writeAsBytes(gifBytes, flush: true);
  return out;
}
