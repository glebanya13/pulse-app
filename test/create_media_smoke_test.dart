import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pulse/features/feed/story_compose.dart';

class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
}

Future<File> _solidPng({
  required int w,
  required int h,
  required int r,
  required int g,
  required int b,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = ui.Color.fromARGB(255, r, g, b),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File(
    '${Directory.systemTemp.path}/pulse_smoke_${r}_${g}_${b}_$w$h.png',
  );
  await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    PathProviderPlatform.instance = _FakePathProvider();
  });

  test('composeSquarePostImage cover-crops to 1:1', () async {
    final src = await _solidPng(w: 1200, h: 800, r: 200, g: 40, b: 40);
    final out = await composeSquarePostImage(source: src, coverCrop: true, size: 240);
    final decoded = img.decodeImage(await out.readAsBytes());
    expect(decoded, isNotNull);
    expect(decoded!.width, 240);
    expect(decoded.height, 240);
  });

  test('composeSquarePostImage contain keeps 1:1 canvas', () async {
    final src = await _solidPng(w: 400, h: 900, r: 40, g: 40, b: 200);
    final out = await composeSquarePostImage(source: src, coverCrop: false, size: 180);
    final decoded = img.decodeImage(await out.readAsBytes());
    expect(decoded, isNotNull);
    expect(decoded!.width, 180);
    expect(decoded.height, 180);
  });

  test('encodeBoomerangGif is forward+reverse ping-pong', () async {
    final frames = <File>[
      await _solidPng(w: 64, h: 64, r: 255, g: 0, b: 0),
      await _solidPng(w: 64, h: 64, r: 0, g: 255, b: 0),
      await _solidPng(w: 64, h: 64, r: 0, g: 0, b: 255),
    ];
    final gif = await encodeBoomerangGif(frames, maxWidth: 64, delayCs: 5);
    expect(await gif.exists(), isTrue);
    final bytes = await gif.readAsBytes();
    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(6)), 'GIF89a');
  });
}
