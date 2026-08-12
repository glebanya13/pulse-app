import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pulse/main.dart';

void main() {
  testWidgets('App boots to the welcome screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: PulseApp()));
    // Avoid pumpAndSettle — progress indicators / pending futures never settle.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('ГОСТИ').evaluate().isNotEmpty) break;
    }

    expect(find.text('ГОСТИ'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}
