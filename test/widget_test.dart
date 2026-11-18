import 'package:flutter_test/flutter_test.dart';
import 'package:smart_laundry_tracker/main.dart';

void main() {
  testWidgets('App renders FindMyFit title and tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartLaundryTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('FindMyFit'), findsWidgets);
    expect(find.text('All Clothes'), findsOneWidget);
    expect(find.text('In Closet'), findsWidgets);
  });
}
