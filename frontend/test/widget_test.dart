import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('App shows login screen when not authenticated', (WidgetTester tester) async {
    await tester.pumpWidget(const PadmaMangalApp());
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Padma Mangal'), findsOneWidget);
  });
}
