import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';

import 'helpers/medication_test_access.dart';

import 'package:sahacare/features/medications/domain/entities/medication_stock.dart';
import 'package:sahacare/features/medications/presentation/widgets/dynamic_medication_bottle.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_stock_card.dart';

StockQuantity q(num value) => StockQuantity((value * 1000).round());
MedicationStock stock(
  num remaining, {
  StockUnit unit = StockUnit.capsule,
  bool enabled = true,
}) => MedicationStock(
  enabled: enabled,
  unit: unit,
  initialQuantity: q(30),
  remaining: q(remaining),
  unitsPerDose: q(1),
  lowThreshold: q(5),
  referenceQuantity: q(30),
);
Widget host(
  MedicationStock value, {
  bool reduced = false,
  VoidCallback? replenish,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: MedicationStockCard(stock: value, onReplenish: replenish),
    ),
  ),
);
MedicationBottlePainter painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is MedicationBottlePainter,
              ),
            )
            .painter!
        as MedicationBottlePainter;

void main() {
  testWidgets(
    'tablet presentation mismatch is visible without changing stock',
    (tester) async {
      final value = stock(20);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MedicationStockCard(
                stock: value,
                commercialPresentation: 'Comprimé',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Présentation et unité à vérifier'),
        findsOneWidget,
      );
      expect(value.unit, StockUnit.capsule);
      expect(value.remaining, q(20));
      await tester.pumpWidget(host(stock(10, unit: StockUnit.tablet)));
      await tester.pumpAndSettle();
      expect(painter(tester).unit, StockUnit.tablet);
      expect(
        find.textContaining('Présentation et unité à vérifier'),
        findsNothing,
      );
    },
  );
  testWidgets(
    'isolated SQLite confirmations, ignore, postponement and restock drive the bottle',
    (tester) async {
      sqfliteFfiInit();
      final repo = MedicationRepository(
        access: testMedicationAccess(),
        allowIsolatedMigration: true,
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(repo.close);
      final day = DateTime(2030, 1, 7);
      late int id;
      late MedicationStock saved;
      await tester.runAsync(() async {
        id = await repo.create(
          Medication(
            name: 'Fictif',
            dosage: 'Dose fictive',
            time: '08:00',
            scheduleTimes: ['08:00', '12:00', '18:00'],
            startDate: day,
            endDate: day,
            reminderEnabled: false,
            stock: stock(30),
          ),
        );
        await repo.ensureOccurrences(from: day, through: day);
        saved = (await repo.getById(id))!.stock!;
      });
      await tester.pumpWidget(host(saved));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final doses = await repo.getOccurrencesForMedication(id);
        await repo.markOccurrenceTaken(doses[0].id);
        await repo.markOccurrenceTaken(doses[0].id);
        await repo.ignoreOccurrence(doses[1].id);
        await repo.postponeOccurrence(
          occurrenceId: doses[2].id,
          date: day,
          time: '20:00',
        );
        saved = (await repo.getById(id))!.stock!;
      });
      await tester.pumpWidget(host(saved));
      await tester.pumpAndSettle();
      expect(find.text('29 gélule(s)'), findsOneWidget);
      expect(painter(tester).level, closeTo(29 / 30, .001));
      await tester.runAsync(() async {
        await repo.replenishStock(id, q(10));
        saved = (await repo.getById(id))!.stock!;
      });
      await tester.pumpWidget(host(saved));
      await tester.pumpAndSettle();
      expect(find.text('39 gélule(s)'), findsOneWidget);
      expect(painter(tester).level, 1);
    },
  );
  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(412, 860),
    Size(440, 956),
  ]) {
    testWidgets('exact quantities and reachable stock actions at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final amount in [30, 20, 10, 5, 0]) {
        await tester.pumpWidget(host(stock(amount)));
        await tester.pumpAndSettle();
        expect(find.text('$amount gélule(s)'), findsOneWidget);
        expect(painter(tester).level, closeTo(amount / 30, .001));
        expect(tester.takeException(), isNull);
      }
      var restocked = 0;
      await tester.pumpWidget(host(stock(0), replenish: () => restocked++));
      final button = find.byKey(const ValueKey('stock-replenish'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      expect(restocked, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'stock decreases and replenishes with finite animations; exact count is immediate',
    (tester) async {
      await tester.pumpWidget(host(stock(30)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(stock(20)));
      expect(find.text('20 gélule(s)'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter(tester).level, greaterThan(20 / 30));
      expect(painter(tester).level, lessThan(1));
      await tester.pumpAndSettle();
      expect(painter(tester).level, closeTo(20 / 30, .001));
      await tester.pumpWidget(host(stock(30)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter(tester).level, greaterThan(20 / 30));
      await tester.pumpAndSettle();
      expect(painter(tester).level, 1);
    },
  );
  testWidgets(
    'fractional liquids, disabled state, enlarged scale and reduced motion',
    (tester) async {
      await tester.pumpWidget(
        host(stock(7.5, unit: StockUnit.milliliter), reduced: true),
      );
      await tester.pump();
      expect(find.text('7,5 mL'), findsOneWidget);
      expect(painter(tester).unit, StockUnit.milliliter);
      expect(painter(tester).level, .25);
      await tester.pumpWidget(host(stock(60), reduced: true));
      await tester.pump();
      expect(painter(tester).level, 1);
      expect(find.textContaining('Échelle visuelle : 60'), findsOneWidget);
      await tester.pumpWidget(host(stock(20, enabled: false), reduced: true));
      await tester.pump();
      expect(painter(tester).level, 0);
      expect(find.text('Suivi désactivé'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
