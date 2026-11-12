import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/entities/medication_stock.dart';
import 'package:sahacare/features/medications/presentation/screens/medications_dashboard_screen.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_dashboard_visuals.dart';

import 'helpers/medication_test_access.dart';

class _Repository extends MedicationRepository {
  _Repository({this.empty = false}) : super(access: testMedicationAccess());
  final bool empty;
  @override
  Future<List<Medication>> getAll() async => empty
      ? []
      : [
          Medication(
            id: 11,
            name: 'Traitement fictif avec un nom très long à afficher',
            dosage: 'Dose fictive',
            time: '08:00',
            scheduleTimes: ['08:00', '20:00'],
            startDate: DateTime.now().subtract(const Duration(days: 1)),
            reminderEnabled: false,
          ),
          Medication(
            id: 12,
            name: 'Terminé fictif',
            dosage: 'Dose fictive',
            time: '08:00',
            startDate: DateTime.now().subtract(const Duration(days: 10)),
            endDate: DateTime.now().subtract(const Duration(days: 2)),
            reminderEnabled: false,
          ),
        ];
}

void main() {
  testWidgets(
    'premium medication card preserves fractional stock and explicit units',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = 0;
      final medication = Medication(
        id: 99,
        name: 'Médicament fictif avec un nom détaillé',
        dosage: '100 mg — dose déclarée',
        time: '08:00',
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        reminderEnabled: false,
        stock: MedicationStock(
          enabled: true,
          unit: StockUnit.milliliter,
          initialQuantity: StockQuantity(10000),
          remaining: StockQuantity(7500),
          unitsPerDose: StockQuantity(500),
          lowThreshold: StockQuantity(2000),
          referenceQuantity: StockQuantity(10000),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: DashboardMedicationCard(
                  medication: medication,
                  onTap: () => opened++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stock : 7,5 mL'), findsOneWidget);
      expect(find.text('Actif'), findsOneWidget);
      await tester.tap(find.byType(DashboardMedicationCard));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(412, 860),
    Size(440, 956),
  ]) {
    testWidgets('dashboard overview, routes and filters at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      addTearDown(repository.access.dispose);
      final destinations = {
        'Mon calendrier thérapeutique': '/medications/schedule',
        'Mes statistiques': '/medications/statistics',
        'Rapport médical': '/medications/report',
        'Scanner une ordonnance': '/medications/scan',
        'Rappels': '/medications/reminders',
      };
      final router = GoRouter(
        initialLocation: '/medications',
        routes: [
          GoRoute(
            path: '/medications',
            builder: (_, _) =>
                MedicationsDashboardScreen(repository: repository),
          ),
          for (final path in {
            ...destinations.values,
            '/medications/add',
            '/medications/detail',
          })
            GoRoute(
              path: path,
              builder: (_, state) =>
                  Scaffold(body: Text('destination:${state.uri}')),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('active-treatment-count')))
            .data,
        '1',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('planned-dose-count')))
            .data,
        '2',
      );
      for (final entry in destinations.entries) {
        await tester.drag(find.byType(ListView), const Offset(0, 4000));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(entry.key), 150);
        await Scrollable.ensureVisible(
          tester.element(find.text(entry.key)),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.text('destination:${entry.value}'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
      }
      await tester.drag(find.byType(ListView), const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Gestion du stock'), 150);
      await tester.ensureVisible(find.text('Gestion du stock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gestion du stock'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(ListTile),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('destination:/medications/detail?id=11'),
        findsOneWidget,
      );
      router.pop();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Terminés'), 150);
      await tester.ensureVisible(find.text('Terminés'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminés'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Terminé fictif'), 100);
      await tester.ensureVisible(find.text('Terminé fictif'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminé fictif'));
      await tester.pumpAndSettle();
      expect(
        find.text('destination:/medications/detail?id=12'),
        findsOneWidget,
      );
      router.pop();
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('add-medication-button'));
      expect(
        tester.getRect(find.byType(ListView)).bottom,
        lessThanOrEqualTo(tester.getRect(button).top),
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('destination:/medications/add'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('empty premium dashboard and reduced motion at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository(empty: true);
      addTearDown(repository.access.dispose);
      final router = GoRouter(
        initialLocation: '/medications',
        routes: [
          GoRoute(
            path: '/medications',
            builder: (_, _) =>
                MedicationsDashboardScreen(repository: repository),
          ),
          GoRoute(
            path: '/medications/add',
            builder: (_, _) =>
                const Scaffold(body: Text('empty add destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.6),
            ),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TweenAnimationBuilder<double>>(
              find.descendant(
                of: find.byType(DashboardHero),
                matching: find.byType(TweenAnimationBuilder<double>),
              ),
            )
            .duration,
        Duration.zero,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('planned-dose-count')),
        100,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('planned-dose-count')))
            .data,
        '0',
      );
      await tester.scrollUntilVisible(find.text('Gestion du stock'), 150);
      await tester.ensureVisible(find.text('Gestion du stock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gestion du stock'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Votre stock commence ici'),
        80,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Votre stock commence ici'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Mon premier traitement'),
        ),
        80,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(
        tester.element(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Mon premier traitement'),
          ),
        ),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Mon premier traitement'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('empty add destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
