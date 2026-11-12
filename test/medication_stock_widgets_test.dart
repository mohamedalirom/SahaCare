import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/domain/entities/medication_stock.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_stock_card.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_stock_form.dart';

void main() {
  StockQuantity q(String value) => StockQuantity.parse(value);
  MedicationStock stock(String remaining, {int anomalies = 0}) =>
      MedicationStock(
        enabled: true,
        unit: StockUnit.tablet,
        initialQuantity: q('10'),
        remaining: q(remaining),
        unitsPerDose: q('0.5'),
        lowThreshold: q('2'),
        referenceQuantity: q('10'),
        pendingAnomalies: anomalies,
      );
  Widget host(Widget child, {double scale = 1}) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );

  testWidgets(
    'stock gauge shows exact quantities and turquoise orange red states',
    (tester) async {
      final gaugeFinder = find.byKey(const ValueKey('stock-gauge'));
      double? previousValue;
      for (final entry in [
        ('8.5', const Color(0xFF0D9488)),
        ('2', const Color(0xFFD97706)),
        ('0', const Color(0xFFDC2626)),
      ]) {
        await tester.pumpWidget(
          host(MedicationStockCard(stock: stock(entry.$1))),
        );
        final target = q(entry.$1).milliUnits / 10000;
        if (previousValue != null) {
          expect(
            tester.widget<LinearProgressIndicator>(gaugeFinder).value,
            closeTo(previousValue, 0.000001),
          );
          await tester.pump(const Duration(milliseconds: 210));
          final intermediate = tester
              .widget<LinearProgressIndicator>(gaugeFinder)
              .value!;
          expect(intermediate, greaterThan(target));
          expect(intermediate, lessThan(previousValue));
        }
        await tester.pumpAndSettle();
        final gauge = tester.widget<LinearProgressIndicator>(gaugeFinder);
        expect(gauge.color, entry.$2);
        expect(gauge.value, closeTo(target, 0.000001));
        previousValue = target;
        expect(find.text('${q(entry.$1).display} comprimé(s)'), findsOneWidget);
      }
      await tester.pumpWidget(
        host(MedicationStockCard(stock: stock('1', anomalies: 1))),
      );
      expect(find.textContaining('à régulariser'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(412, 860)]) {
    testWidgets(
      'stock actions wrap without overflow at $size and enlarged text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          host(
            MedicationStockCard(
              stock: stock('1', anomalies: 1),
              onConfigure: () {},
              onReplenish: () {},
              onCorrect: () {},
              onHistory: () {},
            ),
            scale: 1.3,
          ),
        );
        await tester.ensureVisible(find.text('Mouvements de stock'));
        expect(find.text('Réapprovisionner'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'stock opt in requires explicit unit and accepts exact mL fractions',
    (tester) async {
      final controller = MedicationStockFormController();
      addTearDown(controller.dispose);
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(
          Form(
            key: form,
            child: MedicationStockForm(
              controller: controller,
              presentation: 'Solution 500 mg',
            ),
          ),
        ),
      );
      expect(controller.enabled, isFalse);
      expect(controller.unit, isNull);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(form.currentState!.validate(), isFalse);
      controller.setUnit(StockUnit.milliliter);
      controller.initial.text = '10,5';
      controller.perDose.text = '0,125';
      controller.threshold.text = '2';
      await tester.pump();
      expect(form.currentState!.validate(), isTrue);
      expect(controller.value!.remaining, q('10.5'));
      expect(controller.value!.unitsPerDose, q('0.125'));
      expect(controller.value!.unit, StockUnit.milliliter);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'discrete units reject fractional doses and presentation warning is visible',
    (tester) async {
      final controller = MedicationStockFormController()
        ..setEnabled(true)
        ..setUnit(StockUnit.capsule);
      controller.initial.text = '10';
      controller.perDose.text = '0.5';
      controller.threshold.text = '2';
      addTearDown(controller.dispose);
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(
          Form(
            key: form,
            child: MedicationStockForm(
              controller: controller,
              presentation: 'Gélule',
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      controller.setUnit(StockUnit.tablet);
      await tester.pump();
      expect(form.currentState!.validate(), isTrue);
      expect(
        find.textContaining('ne semble pas être un comprimé'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
