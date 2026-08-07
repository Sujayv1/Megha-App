// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_project/main.dart';

void main() {
  testWidgets('FarmSense app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FarmSenseApp());
    expect(find.text('FarmSense'), findsWidgets);
  });
}
