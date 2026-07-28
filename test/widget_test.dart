import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_wala/main.dart';

void main() {
  testWidgets('Splash screen shows app name', (WidgetTester tester) async {
    await tester.pumpWidget(const CalendarWalaApp());

    expect(find.text('Calendar Wala'), findsOneWidget);
  });
}
