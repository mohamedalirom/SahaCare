import 'helpers/medication_test_access.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahacare/core/widgets/phone_frame_wrapper.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/entities/medication_occurrence.dart';
import 'package:sahacare/features/medications/domain/services/medication_adherence.dart';
import 'package:sahacare/features/medications/presentation/screens/medication_statistics_screen.dart';
import 'package:sahacare/features/medications/presentation/screens/medications_dashboard_screen.dart';

import 'medication_adherence_test.dart' show record;

class _Repository extends MedicationRepository {
  _Repository(this.records) : super(access: testMedicationAccess());
  final List<AdherenceRecord> records;
  int reads = 0;
  bool fail = false;
  @override
  Future<List<AdherenceRecord>> getAdherenceRecords({
    required DateTime from,
    required DateTime through,
  }) async {
    reads++;
    if (fail) throw StateError('injected read error');
    return records;
  }

  @override
  Future<List<Medication>> getAll() async => [];
}

void main() {
  final now = DateTime(2026, 10, 31, 12);
  List<AdherenceRecord> records() => [
    record(
      1,
      DateTime(2026, 10, 31),
      status: MedicationOccurrenceStatus.taken,
      actual: DateTime(2026, 10, 31, 8, 15),
    ),
    record(
      2,
      DateTime(2026, 10, 30),
      status: MedicationOccurrenceStatus.ignored,
      medicationId: 2,
    ),
    record(3, DateTime(2026, 10, 12)),
  ];
  Widget host(_Repository repo, {bool phone = false, double scale = 1}) =>
      MaterialApp(
        builder: (context, child) {
          final content = MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
          return phone ? PhoneFrameWrapper(child: content) : content;
        },
        home: MedicationStatisticsScreen(repository: repo, clock: () => now),
      );
  Future<void> scroll(
    WidgetTester tester,
    Finder finder, {
    double delta = 300,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(412, 860),
    const Size(800, 1000),
  ]) {
    testWidgets('statistics charts and history fit $size with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        host(_Repository(records()), phone: size.width > 550, scale: 1.3),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mes statistiques'), findsOneWidget);
      await scroll(tester, find.byKey(const ValueKey('adherence-rate')));
      expect(find.text('50,0 %'), findsOneWidget);
      await scroll(tester, find.byType(LineChart));
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        chart.data.lineBarsData.single.spots
            .where((s) => s == FlSpot.nullSpot)
            .length,
        5,
      );
      await scroll(tester, find.byType(PieChart));
      expect(
        tester.widget<PieChart>(find.byType(PieChart)).data.sections.length,
        2,
      );
      await scroll(tester, find.text('Historique chronologique'));
      expect(find.text('Confirmée le : 31/10/2026 08:15'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'period selector reloads SQLite snapshot and medication filter recalculates rate',
    (tester) async {
      final repo = _Repository(records());
      await tester.pumpWidget(host(repo));
      await tester.pumpAndSettle();
      expect(find.text('50,0 %'), findsOneWidget);
      await tester.tap(find.text('30 jours'));
      await tester.pumpAndSettle();
      expect(repo.reads, 2);
      expect(find.text('33,3 %'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Médicament 2').last);
      await tester.pumpAndSettle();
      expect(find.text('0,0 %'), findsOneWidget);
      expect(repo.reads, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('daily table filters history and clearing restores all records', (
    tester,
  ) async {
    await tester.pumpWidget(host(_Repository(records())));
    await tester.pumpAndSettle();
    await scroll(tester, find.text('Voir les valeurs quotidiennes'));
    await tester.tap(find.text('Voir les valeurs quotidiennes'));
    await tester.pumpAndSettle();
    await scroll(tester, find.text('30/10'));
    await tester.tap(find.text('30/10'));
    await tester.pumpAndSettle();
    await scroll(tester, find.text('Historique chronologique'));
    expect(find.text('Prévue : 30/10/2026 08:00'), findsOneWidget);
    expect(find.text('Prévue : 31/10/2026 08:00'), findsNothing);
    await tester.tap(find.text('Effacer le filtre 30/10'));
    await tester.pumpAndSettle();
    expect(find.text('Prévue : 31/10/2026 08:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('touching a curve point filters history to its local day', (
    tester,
  ) async {
    await tester.pumpWidget(host(_Repository(records())));
    await tester.pumpAndSettle();
    await scroll(tester, find.byType(LineChart));
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final bar = chart.data.lineBarsData.single;
    chart.data.lineTouchData.touchCallback!(
      FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
      LineTouchResponse(
        touchLocation: Offset.zero,
        touchChartCoordinate: const Offset(6, 100),
        lineBarSpots: [TouchLineBarSpot(bar, 0, bar.spots.last, 0)],
      ),
    );
    await tester.pumpAndSettle();
    await scroll(tester, find.text('Historique chronologique'));
    expect(find.text('Effacer le filtre 31/10'), findsOneWidget);
    expect(find.text('Prévue : 31/10/2026 08:00'), findsOneWidget);
    expect(find.text('Prévue : 30/10/2026 08:00'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty data shows undefined rate and no fabricated charts', (
    tester,
  ) async {
    await tester.pumpWidget(host(_Repository([])));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
    await scroll(tester, find.text('Aucune donnée enregistrée'));
    expect(find.byType(LineChart), findsNothing);
    expect(find.byType(PieChart), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'read errors offer retry and refresh updates time-based statuses',
    (tester) async {
      final repo = _Repository(records())..fail = true;
      await tester.pumpWidget(host(repo));
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('50,0 %'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('statistics-refresh')));
      await tester.pumpAndSettle();
      expect(repo.reads, 3);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('minute refresh reclassifies due records without creating data', (
    tester,
  ) async {
    var clock = now;
    final repo = _Repository([
      record(1, DateTime(2026, 10, 31), time: '11:30'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: MedicationStatisticsScreen(repository: repo, clock: () => clock),
      ),
    );
    await tester.pumpAndSettle();
    await scroll(tester, find.byType(PieChart));
    expect(
      tester.widget<PieChart>(find.byType(PieChart)).data.sections.single.color,
      const Color(0xFF0284C7),
    );
    clock = DateTime(2026, 10, 31, 12, 30);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    await scroll(tester, find.byType(PieChart));
    expect(
      tester.widget<PieChart>(find.byType(PieChart)).data.sections.single.color,
      const Color(0xFFD97706),
    );
    expect(repo.reads, 2);
    expect(repo.records.length, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dashboard statistics action opens the dedicated route', (
    tester,
  ) async {
    final repo = _Repository([]);
    final router = GoRouter(
      initialLocation: '/medications',
      routes: [
        GoRoute(
          path: '/medications',
          builder: (context, state) =>
              MedicationsDashboardScreen(repository: repo),
        ),
        GoRoute(
          path: '/medications/statistics',
          builder: (context, state) =>
              MedicationStatisticsScreen(repository: repo, clock: () => now),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await scroll(tester, find.text('Mes statistiques'));
    await tester.tap(find.text('Mes statistiques'));
    await tester.pumpAndSettle();
    expect(find.byType(MedicationStatisticsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
