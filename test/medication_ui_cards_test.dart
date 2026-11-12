import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/domain/entities/medication_stock.dart';
import 'package:sahacare/features/medications/domain/services/medication_adherence.dart';
import 'package:sahacare/features/medications/presentation/widgets/adherence_dashboard_cards.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_stock_card.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_visuals.dart';

void main() {
  Widget host(Widget child, {double scale = 1}) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    ),
  );
  for (final size in [const Size(320, 568), const Size(412, 860)]) {
    testWidgets(
      'status cards stay readable at $size and preserve zero-data semantics',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final report = MedicationAdherenceCalculator().calculate(
          [],
          days: 7,
          now: DateTime(2026, 10, 31, 12),
        );
        await tester.pumpWidget(
          host(
            Column(
              children: [
                AdherenceOverviewCard(report: report, formattedRate: '—'),
                AdherenceStatusGrid(
                  report: report,
                  colorFor: (_) => MedicationColors.teal,
                ),
              ],
            ),
            scale: 1.5,
          ),
        );
        expect(find.byKey(const ValueKey('adherence-rate')), findsOneWidget);
        for (final status in AdherenceStatus.values.where(
          (s) => s != AdherenceStatus.future,
        )) {
          expect(
            find.byKey(ValueKey('adherence-status-${status.name}')),
            findsOneWidget,
          );
        }
        expect(report.percentage, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'stock badges reflect existing model states and actions retain their callbacks',
    (tester) async {
      StockQuantity q(String text) => StockQuantity.parse(text);
      MedicationStock stock(
        String remaining, {
        bool enabled = true,
        int anomalies = 0,
      }) => MedicationStock(
        enabled: enabled,
        unit: StockUnit.milliliter,
        initialQuantity: q('10'),
        remaining: q(remaining),
        unitsPerDose: q('1.25'),
        lowThreshold: q('2'),
        referenceQuantity: q('10'),
        pendingAnomalies: anomalies,
      );
      for (final item in [
        (stock('8.5'), 'Stock normal'),
        (stock('2'), 'Stock faible'),
        (stock('0'), 'Stock critique · épuisé'),
        (stock('1', anomalies: 1), 'À régulariser'),
        (stock('8', enabled: false), 'Suivi désactivé'),
      ]) {
        await tester.pumpWidget(host(MedicationStockCard(stock: item.$1)));
        expect(find.text(item.$2), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('stock-remaining')))
              .data,
          '${item.$1.remaining.display} mL',
        );
      }
      final actions = <String>[];
      await tester.pumpWidget(
        host(
          MedicationStockCard(
            stock: null,
            onConfigure: () => actions.add('activate'),
          ),
        ),
      );
      await tester.tap(find.text('Activer le suivi'));
      await tester.pumpWidget(
        host(
          MedicationStockCard(
            stock: stock('8.5'),
            onConfigure: () => actions.add('configure'),
            onReplenish: () => actions.add('replenish'),
            onCorrect: () => actions.add('correct'),
            onHistory: () => actions.add('history'),
          ),
        ),
      );
      for (final label in [
        'Réglages du stock',
        'Réapprovisionner',
        'Corriger la quantité',
        'Mouvements de stock',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
      }
      expect(actions, [
        'activate',
        'configure',
        'replenish',
        'correct',
        'history',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}
