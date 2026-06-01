import 'package:flutter_test/flutter_test.dart';
import 'package:bharatam_lms/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BharatamLMSApp());
    expect(find.text('Bharatam LMS'), findsOneWidget);
  });
}
