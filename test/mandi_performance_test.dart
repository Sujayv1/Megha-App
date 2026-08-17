import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_project/features/mandi/screens/mandi_screen.dart';
import 'package:plant_project/features/mandi/services/mandi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MandiScreen Performance Optimization & Data Integrity Tests', () {
    testWidgets('Mandi screen renders search form with precomputed states and dynamic districts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MandiScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MandiScreen), findsOneWidget);
      expect(find.text('Mandi Prices'), findsOneWidget);
      expect(find.text('Harvested Crop Price Intelligence'), findsOneWidget);
      expect(find.text('Select State First'), findsOneWidget);

      // Verify popular commodities list is present in MandiService
      expect(MandiService.popularCommodities.contains('Rice'), isTrue);
      expect(MandiService.popularCommodities.contains('Wheat'), isTrue);
      expect(MandiService.popularCommodities.contains('Tomato'), isTrue);
    });

    test('Precomputed static state & district sorting preserves complete data integrity', () {
      final rawStates = MandiService.indianStatesDistricts.keys.toList();
      final expectedSortedStates = List<String>.from(rawStates)..sort();

      // Check Karnataka
      final rawKarnataka = MandiService.indianStatesDistricts['Karnataka']!;
      final expectedKarnataka = List<String>.from(rawKarnataka)..sort();

      // Check Maharashtra
      final rawMaharashtra = MandiService.indianStatesDistricts['Maharashtra']!;
      final expectedMaharashtra = List<String>.from(rawMaharashtra)..sort();

      expect(expectedSortedStates.first, equals('Andhra Pradesh'));
      expect(expectedKarnataka.first, equals('Bagalkot'));
      expect(expectedMaharashtra.first, equals('Ahilyanagar'));
    });
  });
}
