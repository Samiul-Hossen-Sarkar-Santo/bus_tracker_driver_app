import 'package:flutter_test/flutter_test.dart';

import 'package:bus_tracker_driver_app/main.dart';

void main() {
  testWidgets('Loading screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('By the Students, For the Students!'), findsOneWidget);
  });
}
