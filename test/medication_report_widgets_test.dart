import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahacare/core/widgets/phone_frame_wrapper.dart';
import 'package:sahacare/features/medications/data/services/medication_report_service.dart';
import 'package:sahacare/features/medications/data/services/medication_report_actions.dart';
import 'package:sahacare/features/medications/domain/entities/medication_report.dart';
import 'package:sahacare/features/medications/presentation/screens/medication_report_screen.dart';
import 'package:sahacare/features/medications/presentation/screens/medications_dashboard_screen.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';

import 'medication_report_test.dart'
    show ReportMemoryRepository, reportFixture, reportNow, demoReportSession;

class _Service extends MedicationReportService {
  _Service({MedicationReportSessionReader? reader})
    : super(
        repository: ReportMemoryRepository(reportFixture()),
        sessionReader: reader ?? demoReportSession,
        clock: () => reportNow,
      );
  MedicationReportOptions? last;
  @override
  Future<MedicationReportArtifact> generate(
    MedicationReportOptions options, {
    required bool acknowledgeAnonymous,
  }) async {
    last = options;
    final data = await collect(
      options,
      acknowledgeAnonymous: acknowledgeAnonymous,
    );
    return MedicationReportArtifact(
      bytes: Uint8List.fromList([37, 80, 68, 70, 45]),
      filename: 'fictif.pdf',
      sessionKey: requireAccess().key,
      data: data,
    );
  }
}

class _Actions extends MedicationReportActions {
  int saves = 0, shares = 0;
  @override
  Future<String> save(MedicationReportArtifact artifact) async {
    saves++;
    return 'Enregistrement fictif du test uniquement';
  }

  @override
  Future<ReportShareOutcome> share(
    MedicationReportArtifact artifact, {
    required Rect origin,
  }) async {
    shares++;
    return ReportShareOutcome.dismissed;
  }
}

class _DashboardRepository extends ReportMemoryRepository {
  _DashboardRepository() : super(reportFixture());
  @override
  Future<List<Medication>> getAll() async => [];
}

void main() {
  Widget host(_Service service, _Actions actions, {bool phone = false}) =>
      MaterialApp(
        builder: phone
            ? (context, child) => PhoneFrameWrapper(child: child!)
            : null,
        home: MedicationReportScreen(
          service: service,
          actions: actions,
          previewBuilder: (_) =>
              const Center(child: Text('Aperçu PDF de test')),
        ),
      );
  Future<void> scroll(
    WidgetTester tester,
    Finder target, {
    double delta = 200,
  }) async {
    await tester.scrollUntilVisible(
      target,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> generate(WidgetTester tester) async {
    await scroll(
      tester,
      find.byKey(const ValueKey('report-anonymous-consent')),
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await scroll(tester, find.byKey(const ValueKey('report-generate')));
    await tester.tap(find.byKey(const ValueKey('report-generate')));
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(320, 568),
    const Size(412, 860),
    const Size(800, 1000),
  ]) {
    testWidgets(
      'report consent options preview and actions fit $size without auto sharing',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _Service();
        final actions = _Actions();
        await tester.pumpWidget(
          host(service, actions, phone: size.width > 550),
        );
        await tester.pumpAndSettle();
        expect(find.text('Mon rapport médical'), findsOneWidget);
        await generate(tester);
        await scroll(tester, find.text('Aperçu PDF de test'));
        expect(service.last, isNotNull);
        expect(actions.saves, 0);
        expect(actions.shares, 0);
        await scroll(tester, find.byKey(const ValueKey('report-save')));
        await tester.tap(find.byKey(const ValueKey('report-save')));
        await tester.pumpAndSettle();
        expect(actions.saves, 1);
        await scroll(tester, find.byKey(const ValueKey('report-share')));
        await tester.tap(find.byKey(const ValueKey('report-share')));
        await tester.pumpAndSettle();
        expect(actions.shares, 1);
        expect(
          find.text('Partage annulé. Aucun nouvel envoi demandé.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'thirty day selector and options are passed to generator, edits invalidate preview',
    (tester) async {
      final service = _Service();
      final actions = _Actions();
      await tester.pumpWidget(host(service, actions));
      await tester.pumpAndSettle();
      await scroll(tester, find.text('30 jours'));
      await tester.tap(find.text('30 jours'));
      await tester.pumpAndSettle();
      await scroll(tester, find.text('Inclure l’historique des prises'));
      await tester.tap(find.text('Inclure l’historique des prises'));
      await tester.pumpAndSettle();
      await generate(tester);
      expect(service.last!.from, DateTime(2026, 10, 2));
      expect(service.last!.includeHistory, isFalse);
      await scroll(
        tester,
        find.text('Inclure les traitements terminés ou archivés'),
        delta: -200,
      );
      await tester.tap(
        find.text('Inclure les traitements terminés ou archivés'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-share')), findsNothing);
      expect(actions.shares, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'custom range dialog updates explicit dates without claiming seven day selection',
    (tester) async {
      final service = _Service();
      await tester.pumpWidget(host(service, _Actions()));
      await tester.pumpAndSettle();
      await scroll(tester, find.byKey(const ValueKey('report-custom-period')));
      await tester.tap(find.byKey(const ValueKey('report-custom-period')));
      await tester.pumpAndSettle();
      final dialog = find.byType(DateRangePickerDialog);
      expect(dialog, findsOneWidget);
      Navigator.of(tester.element(dialog)).pop(
        DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 10, 12)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        isEmpty,
      );
      await generate(tester);
      expect(service.last!.from, DateTime(2026, 9, 1));
      expect(service.last!.through, DateTime(2026, 10, 12));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'account export is blocked before reading unscoped local records',
    (tester) async {
      final service = _Service(
        reader: () => const MedicationReportSession(
          key: 'real-patient',
          localDemo: false,
        ),
      );
      await tester.pumpWidget(host(service, _Actions()));
      await tester.pumpAndSettle();
      await scroll(tester, find.byKey(const ValueKey('report-generate')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('report-generate')))
            .onPressed,
        isNull,
      );
      expect((service.repository as ReportMemoryRepository).reads, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('dashboard report shortcut opens its own route', (tester) async {
    final router = GoRouter(
      initialLocation: '/medications',
      routes: [
        GoRoute(
          path: '/medications',
          builder: (context, state) =>
              MedicationsDashboardScreen(repository: _DashboardRepository()),
        ),
        GoRoute(
          path: '/medications/report',
          builder: (context, state) => MedicationReportScreen(
            service: _Service(),
            actions: _Actions(),
            previewBuilder: (_) => const SizedBox(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await scroll(tester, find.text('Rapport médical'));
    await tester.tap(find.text('Rapport médical'));
    await tester.pumpAndSettle();
    expect(find.byType(MedicationReportScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
