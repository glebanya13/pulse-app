import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pulse/main.dart';

/// The test sandbox has no network access. Rather than let every
/// Image.network / CachedNetworkImage in the mock data fail loudly, serve a
/// tiny transparent PNG for any request so image widgets resolve normally —
/// the app fetches real images fine on-device, as verified separately on a
/// simulator.
const _transparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

class _FakeImageHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentPng]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A bounded number of fixed pumps instead of pumpAndSettle, which throws on
/// any indefinitely-animating widget (e.g. a CircularProgressIndicator).
Future<void> _settle(WidgetTester tester, {int times = 6}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUpAll(() => HttpOverrides.global = _FakeImageHttpOverrides());

  testWidgets('sign in, browse map/events/requests/profile tabs, open an event',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: PulseApp()));
    await _settle(tester);

    // Welcome -> Login
    expect(find.text('ГОСТИ'), findsOneWidget);
    await tester.tap(find.text('Войти'));
    await _settle(tester);

    // Enter phone, request code
    await tester.enterText(find.byType(TextField).first, '+79001234567');
    await tester.tap(find.text('Получить код'));
    await _settle(tester);

    // Enter dev code and verify
    expect(find.text('Подтверждение'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '0000');
    await tester.tap(find.text('Подтвердить'));
    await _settle(tester);

    // Should land on the map tab inside the main shell (bottom nav visible).
    expect(find.text('События'), findsWidgets);
    expect(find.text('Запросы'), findsWidgets);
    expect(find.text('Профиль'), findsWidgets);

    // Switch to Events tab.
    await tester.tap(find.text('События').first);
    await _settle(tester);
    expect(find.text('Ужин с пастой и вином'), findsWidgets);

    // Requests tab.
    await tester.tap(find.text('Запросы').first);
    await _settle(tester);
    expect(find.text('Срочно нужен повар на ужин'), findsWidgets);

    // Profile tab.
    await tester.tap(find.text('Профиль').first);
    await _settle(tester);
    expect(find.text('Денис, 30 лет'), findsOneWidget);
    expect(find.text('Мои события'), findsOneWidget);

    // Back to Events tab, open the first event, then return.
    await tester.tap(find.text('События').first);
    await _settle(tester);
    await tester.tap(find.text('Ужин с пастой и вином').first);
    await _settle(tester);
    expect(find.text('Подать заявку'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await _settle(tester, times: 10);
    expect(find.text('Ужин с пастой и вином'), findsWidgets);
  });
}
