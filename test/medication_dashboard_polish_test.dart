import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/entities/medication_stock.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_dashboard_visuals.dart';

Medication fixture(
  String presentation,
  StockUnit unit, {
  bool enabled = true,
}) => Medication(
  id: 42,
  name: 'Traitement fictif',
  dosage: '500 mg',
  time: '08:00',
  startDate: DateTime(2026),
  reminderEnabled: false,
  commercialPresentation: presentation,
  stock: MedicationStock(
    enabled: enabled,
    unit: unit,
    initialQuantity: StockQuantity(30000),
    remaining: StockQuantity(8000),
    unitsPerDose: StockQuantity(1000),
    lowThreshold: StockQuantity(2000),
    referenceQuantity: StockQuantity(30000),
  ),
);

void main() {
  test(
    'explicit contradictory presentations are flagged without conversion',
    () {
      expect(
        hasDashboardStockPresentationMismatch(
          fixture('Comprimé', StockUnit.capsule),
        ),
        isTrue,
      );
      expect(
        hasDashboardStockPresentationMismatch(
          fixture('Gélules', StockUnit.tablet),
        ),
        isTrue,
      );
      for (final item in [
        fixture('Comprimé', StockUnit.tablet),
        fixture('Comprimés ou gélules', StockUnit.capsule),
        fixture('500 mg', StockUnit.capsule),
        fixture('Solution', StockUnit.milliliter),
        fixture('Comprimé', StockUnit.milligram),
        fixture('Comprimé', StockUnit.capsule, enabled: false),
      ]) {
        expect(hasDashboardStockPresentationMismatch(item), isFalse);
      }
    },
  );

  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(412, 860),
    Size(440, 956),
  ]) {
    testWidgets('stock warning stays readable and read-only at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final medication = fixture('Comprimé', StockUnit.capsule);
      var review = 0;
      var open = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: DashboardMedicationCard(
                medication: medication,
                onTap: () => open++,
                onReviewStock: () => review++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('stock-presentation-warning-42')),
        findsOneWidget,
      );
      expect(find.text('Stock : 8 gélule(s)'), findsOneWidget);
      final button = find.text('Vérifier la présentation et le stock');
      await tester.ensureVisible(button);
      await tester.tap(button);
      expect(review, 1);
      expect(open, 0);
      expect(medication.stock!.remaining, StockQuantity(8000));
      expect(medication.stock!.unit, StockUnit.capsule);
      expect(tester.takeException(), isNull);
    });
  }
}
