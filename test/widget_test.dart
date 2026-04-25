import 'package:flutter_test/flutter_test.dart';

import 'package:bloc_clean_architecture/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const App());

    // Verifies the Page Title.
    expect(find.text('BLoC - Clean Architecture'), findsOneWidget);
  });
}
