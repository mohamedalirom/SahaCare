import 'helpers/medication_test_access.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_stock_section.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/entities/medication_stock.dart';

void main() {
  StockQuantity q(String value) => StockQuantity.parse(value);
  testWidgets('restock and physical reconciliation require explicit actions', (
    tester,
  ) async {
    final repo = _StockRepository();
    late Medication medication;
    final day = DateTime(2030, 1, 7);
    medication = Medication(
      id: 1,
      name: 'Fictif',
      dosage: '500 mg',
      time: '08:00',
      startDate: day,
      endDate: day,
      reminderEnabled: false,
      stock: MedicationStock(
        enabled: true,
        unit: StockUnit.tablet,
        initialQuantity: q('1'),
        remaining: q('1'),
        unitsPerDose: q('2'),
        lowThreshold: q('2'),
        referenceQuantity: q('1'),
      ),
    );
    medication = medication.copyWith(
      stock: medication.stock!.copyWith(pendingAnomalies: 1),
    );
    repo.medication = medication;
    var changed = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MedicationStockSection(
              medication: medication,
              repository: repo,
              onConfigure: () async {},
              onChanged: () {
                if (!changed.isCompleted) changed.complete();
              },
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('stock-replenish')));
    await tester.tap(find.byKey(const ValueKey('stock-replenish')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('stock-dialog-quantity')),
      '4',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.runAsync(
      () => changed.future.timeout(const Duration(seconds: 10)),
    );
    await tester.pumpAndSettle();
    expect(find.text('5 comprimé(s)'), findsOneWidget);
    expect(find.textContaining('à régulariser'), findsOneWidget);
    // Let the transient success snackbar dismiss before the next action.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    changed = Completer<void>();
    await tester.ensureVisible(find.text('Corriger la quantité'));
    await tester.tap(find.text('Corriger la quantité'));
    await tester.runAsync(() async {
      await repo.stockMovements(medication.id!);
    });
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    await tester.enterText(
      find.byKey(const ValueKey('stock-dialog-quantity')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('stock-dialog-reason')),
      'Comptage incluant la prise',
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.runAsync(
      () => changed.future.timeout(const Duration(seconds: 10)),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 comprimé(s)'), findsOneWidget);
    expect(find.textContaining('à régulariser'), findsNothing);
    await tester.runAsync(() async {
      final moves = await repo.stockMovements(medication.id!);
      expect(
        moves
            .where((m) => m.kind == 'inventory_reconciliation')
            .single
            .delta
            .milliUnits,
        0,
      );
      expect(repo.reconciledIds, [7]);
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(repo.close);
  });
}

class _StockRepository extends MedicationRepository {
  _StockRepository() : super(access: testMedicationAccess());
  late Medication medication;
  List<int> reconciledIds = [];
  bool resolved = false;
  @override
  Future<Medication?> getById(int id) async => medication;
  @override
  Future<void> replenishStock(int medicationId, StockQuantity quantity) async {
    medication = medication.copyWith(
      stock: medication.stock!.copyWith(
        remaining: medication.stock!.remaining + quantity,
      ),
    );
  }

  @override
  Future<void> correctStockQuantity(
    int medicationId,
    StockQuantity quantity, {
    required String reason,
    List<int> reconciledAnomalyIds = const [],
  }) async {
    reconciledIds = reconciledAnomalyIds;
    resolved = reconciledIds.isNotEmpty;
    medication = medication.copyWith(
      stock: medication.stock!.copyWith(
        remaining: quantity,
        pendingAnomalies: resolved ? 0 : 1,
      ),
    );
  }

  @override
  Future<List<StockMovement>> stockMovements(int medicationId) async => [
    StockMovement.fromMap({
      'id': 7,
      'kind': resolved ? 'inventory_reconciliation' : 'anomaly',
      'delta_milli': 0,
      'required_milli': 2000,
      'quantity_after_milli': 1000,
      'unit': 'tablet',
      'created_at': '2030-01-07T08:00:00',
      'unresolved': resolved ? 0 : 1,
    }),
  ];
}
