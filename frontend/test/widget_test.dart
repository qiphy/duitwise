import 'package:flutter_test/flutter_test.dart';
import 'package:duitwise/main.dart'; // Fixed package reference

void main() {
  testWidgets('Financial Literacy App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FinancialLiteracyApp());

    // Verify that the static subtitle renders successfully on the screen
    expect(find.text('Ready to be money smart today?'), findsOneWidget);
    
    // Verify that our mascot avatar placeholder exists on the dashboard layout
    expect(find.text('🐯'), findsOneWidget);
  });
}