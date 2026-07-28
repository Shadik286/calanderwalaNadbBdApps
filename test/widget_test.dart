import 'package:flutter_test/flutter_test.dart';

import 'package:reminder_24/main.dart';

void main() {
  testWidgets('Splash screen shows app name', (WidgetTester tester) async {
    await tester.pumpWidget(const Reminder24App());

    expect(find.text('Reminder 24'), findsOneWidget);
  });
}
