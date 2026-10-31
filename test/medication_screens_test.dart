import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahacare/core/widgets/phone_frame_wrapper.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/entities/medication_occurrence.dart';
import 'package:sahacare/features/medications/presentation/screens/edit_medication_screen.dart';
import 'package:sahacare/features/medications/presentation/screens/medication_detail_screen.dart';
import 'package:sahacare/features/medications/presentation/screens/medication_schedule_screen.dart';
import 'package:sahacare/features/medications/presentation/screens/medications_dashboard_screen.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_calendar_widgets.dart';

void main() {
  for (final size in const [Size(320, 568), Size(360, 640), Size(412, 860)]) {
    testWidgets('add action never covers the list at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _MemoryMedicationRepository(
        Medication(
          id: 1,
          name: 'Traitement du jour',
          dosage: '1 comprimé',
          time: '08:00',
          startDate: DateTime.now(),
          reminderEnabled: false,
        ),
      );
      final router = GoRouter(
        initialLocation: '/medications',
        routes: [
          GoRoute(
            path: '/medications',
            builder: (context, state) =>
                MedicationsDashboardScreen(repository: repository),
          ),
          GoRoute(
            path: '/medications/add',
            builder: (context, state) =>
                const Scaffold(body: Text('Formulaire ajout')),
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(repository.close);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final add = find.byKey(const ValueKey('add-medication-button'));
      final actionRect = tester.getRect(add);
      expect(
        tester.getRect(find.byType(ListView)).bottom,
        lessThanOrEqualTo(actionRect.top),
      );
      await tester.scrollUntilVisible(find.text('Aujourd’hui'), 150);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(ListView)).bottom,
        lessThanOrEqualTo(tester.getRect(add).top),
      );
      expect(tester.getRect(add), actionRect);
      expect(tester.takeException(), isNull);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('Formulaire ajout'), findsOneWidget);
    });
  }

  testWidgets('dashboard clears the simulated notch and floating navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryMedicationRepository(
      Medication(
        id: 1,
        name: 'Traitement',
        dosage: '1 comprimé',
        time: '08:00',
        startDate: DateTime.now(),
        reminderEnabled: false,
      ),
    );
    addTearDown(repository.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => PhoneFrameWrapper(child: child!),
        home: MedicationsDashboardScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    final frame = tester.getRect(find.byType(ClipRRect).first);
    expect(
      tester.getTopLeft(find.text('Médicaments & Traitements')).dy,
      greaterThanOrEqualTo(frame.top + 48),
    );
    expect(
      tester
          .getBottomLeft(find.byKey(const ValueKey('add-medication-button')))
          .dy,
      lessThanOrEqualTo(frame.bottom - 100),
    );
    await tester.scrollUntilVisible(
      find.text('Rappels'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.text('Rappels')).dy,
      lessThan(frame.bottom - 100),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard fits a small screen with system safe insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final repository = _MemoryMedicationRepository(
      Medication(
        id: 1,
        name: 'Traitement',
        dosage: '1 comprimé',
        time: '08:00',
        startDate: DateTime.now(),
        reminderEnabled: false,
      ),
    );
    addTearDown(repository.close);
    await tester.pumpWidget(
      MaterialApp(home: MedicationsDashboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Médicaments & Traitements')).dy,
      greaterThanOrEqualTo(24),
    );
    expect(
      tester
          .getBottomLeft(find.byKey(const ValueKey('add-medication-button')))
          .dy,
      lessThanOrEqualTo(568 - 20 - 100),
    );
    await tester.scrollUntilVisible(find.text('Rappels'), 150);
    expect(tester.takeException(), isNull);
  });

  test('calendar indicators follow recorded occurrence status', () {
    final occurrence = MedicationOccurrence(
      id: 1,
      medicationId: 1,
      scheduleId: 1,
      scheduledDate: DateTime(2026, 10, 8),
      scheduledTime: '08:00',
      status: MedicationOccurrenceStatus.taken,
      medicationName: 'Traitement',
      dosage: '1 comprimé',
      medicationStartDate: DateTime(2026, 10, 8),
    );

    expect(medicationOccurrenceColor(occurrence), const Color(0xFF16A34A));
    expect(
      medicationOccurrenceColor(
        MedicationOccurrence(
          id: 2,
          medicationId: 1,
          scheduleId: 1,
          scheduledDate: DateTime(2026, 10, 8),
          scheduledTime: '09:00',
          status: MedicationOccurrenceStatus.ignored,
          medicationName: 'Traitement',
          dosage: '1 comprimé',
          medicationStartDate: DateTime(2026, 10, 8),
        ),
      ),
      const Color(0xFFDC2626),
    );
  });

  testWidgets(
    'dashboard opens real details and refreshes after edit and delete',
    (tester) async {
      final repository = _MemoryMedicationRepository(
        Medication(
          id: 1,
          name: 'Doliprane',
          dosage: '500 mg',
          time: '08:00',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 7)),
          reminderEnabled: true,
          activeIngredient: 'Paracétamol',
          commercialPresentation: '500 mg • Comprimé',
        ),
      );

      final router = GoRouter(
        initialLocation: '/medications',
        routes: [
          GoRoute(
            path: '/medications',
            builder: (context, state) =>
                MedicationsDashboardScreen(repository: repository),
          ),
          GoRoute(
            path: '/medications/detail',
            builder: (context, state) => MedicationDetailScreen(
              medicationId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
              repository: repository,
            ),
          ),
          GoRoute(
            path: '/medications/edit',
            builder: (context, state) => EditMedicationScreen(
              medicationId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
              repository: repository,
            ),
          ),
        ],
      );
      addTearDown(() async {
        router.dispose();
        await repository.close();
      });

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Doliprane'), findsOneWidget);
      expect(find.text('500 mg • 08:00'), findsOneWidget);
      expect(find.text('Substance active : Paracétamol'), findsOneWidget);
      expect(find.text('Présentation : 500 mg • Comprimé'), findsOneWidget);

      await tester.tap(find.text('Doliprane'));
      await tester.pumpAndSettle();
      expect(find.text('Détail du traitement'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('500 mg'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('500 mg'), findsOneWidget);
      expect(find.text('Paracétamol'), findsOneWidget);
      expect(find.text('500 mg • Comprimé'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Horaires de prise'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Horaires de prise'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Modifier le traitement'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Modifier le traitement'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Doliprane modifié',
      );
      await tester.scrollUntilVisible(
        find.text('Enregistrer les modifications'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final saveButton = find.ancestor(
        of: find.text('Enregistrer les modifications'),
        matching: find.byType(ElevatedButton),
      );
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Doliprane modifié'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();
      expect(find.text('Doliprane modifié'), findsOneWidget);
      expect(find.text('500 mg • 08:00'), findsOneWidget);

      await tester.tap(find.text('Doliprane modifié'));
      await tester.pumpAndSettle();
      expect(find.text('Détail du traitement'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Supprimer le traitement'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final deleteButton = find.ancestor(
        of: find.text('Supprimer le traitement'),
        matching: find.byType(OutlinedButton),
      );
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(await repository.getById(1), isNull);
      expect(find.text('Aucun médicament enregistré'), findsOneWidget);
    },
  );

  testWidgets(
    'dashboard calendar card and schedule shortcut open the calendar',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _MemoryMedicationRepository(
        Medication(
          id: 11,
          name: 'Traitement calendrier',
          dosage: '1 comprimé',
          time: '08:00',
          startDate: DateTime.now(),
          reminderEnabled: false,
          scheduleTimes: const ['08:00', '20:00'],
        ),
      );
      final router = GoRouter(
        initialLocation: '/medications',
        routes: [
          GoRoute(
            path: '/medications',
            builder: (context, state) =>
                MedicationsDashboardScreen(repository: repository),
          ),
          GoRoute(
            path: '/medications/schedule',
            builder: (context, state) =>
                MedicationScheduleScreen(repository: repository),
          ),
        ],
      );
      addTearDown(() async {
        router.dispose();
        await repository.close();
      });

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Mon calendrier thérapeutique'), findsOneWidget);
      expect(
        find.text('Consultez vos prises par jour, semaine ou mois'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('open-medication-calendar')));
      await tester.pumpAndSettle();
      expect(find.text('Calendrier thérapeutique'), findsOneWidget);
      expect(find.text('Jour'), findsOneWidget);
      expect(find.text('Semaine'), findsOneWidget);
      expect(find.text('Mois'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Horaires de prise'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Horaires de prise'));
      await tester.pumpAndSettle();
      expect(find.text('Calendrier thérapeutique'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calendar switches between week and month views', (tester) async {
    final repository = _MemoryMedicationRepository(
      Medication(
        id: 2,
        name: 'Traitement continu',
        dosage: '1 comprimé',
        time: '09:00',
        startDate: DateTime.now().subtract(const Duration(days: 2)),
        reminderEnabled: false,
        scheduleTimes: const ['09:00', '18:00'],
      ),
    );
    final router = GoRouter(
      initialLocation: '/medications/schedule',
      routes: [
        GoRoute(
          path: '/medications/schedule',
          builder: (context, state) =>
              MedicationScheduleScreen(repository: repository),
        ),
        GoRoute(
          path: '/medications/detail',
          builder: (context, state) => MedicationDetailScreen(
            medicationId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
            repository: repository,
          ),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await repository.close();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Calendrier thérapeutique'), findsOneWidget);
    expect(find.text('Jour'), findsOneWidget);
    expect(find.text('Semaine'), findsOneWidget);
    expect(find.text('Mois'), findsOneWidget);
    final initialMonthTitle = tester
        .widget<Text>(find.textContaining(DateTime.now().year.toString()))
        .data!;
    await tester.tap(find.byTooltip('Période suivante'));
    await tester.pumpAndSettle();
    expect(find.text(initialMonthTitle), findsNothing);

    await tester.tap(find.text('Mois'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);

    final nextMonthTitle = tester
        .widget<Text>(find.textContaining(DateTime.now().year.toString()))
        .data!;
    await tester.tap(find.byTooltip('Période suivante'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text(nextMonthTitle), findsNothing);
  });

  testWidgets('calendar link opens the three-view medication calendar', (
    tester,
  ) async {
    final repository = _MemoryMedicationRepository(
      Medication(
        id: 8,
        name: 'Traitement navigation',
        dosage: '1 comprimé',
        time: '08:00',
        startDate: DateTime.now(),
        reminderEnabled: false,
      ),
    );
    final router = GoRouter(
      initialLocation: '/medications',
      routes: [
        GoRoute(
          path: '/medications',
          builder: (context, state) =>
              MedicationsDashboardScreen(repository: repository),
        ),
        GoRoute(
          path: '/medications/schedule',
          builder: (context, state) =>
              MedicationScheduleScreen(repository: repository),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await repository.close();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Horaires de prise'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Horaires de prise'));
    await tester.pumpAndSettle();

    expect(find.text('Calendrier thérapeutique'), findsOneWidget);
    expect(find.text('Jour'), findsOneWidget);
    expect(find.text('Semaine'), findsOneWidget);
    expect(find.text('Mois'), findsOneWidget);
  });

  testWidgets('daily view renders actual occurrence details and statuses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateUtils.dateOnly(DateTime.now());
    final repository = _MemoryMedicationRepository(
      Medication(
        id: 9,
        name: 'Traitement timeline',
        dosage: '500 mg',
        time: '08:00',
        startDate: today,
        reminderEnabled: false,
        scheduleTimes: const ['08:00', '18:00'],
      ),
      occurrences: [
        MedicationOccurrence(
          id: 20,
          medicationId: 9,
          scheduleId: 1,
          scheduledDate: today,
          scheduledTime: '08:00',
          status: MedicationOccurrenceStatus.taken,
          medicationName: 'Traitement timeline',
          dosage: '500 mg',
          medicationStartDate: today,
        ),
        MedicationOccurrence(
          id: 21,
          medicationId: 9,
          scheduleId: 1,
          scheduledDate: today,
          scheduledTime: '18:00',
          status: MedicationOccurrenceStatus.scheduled,
          medicationName: 'Traitement timeline',
          dosage: '500 mg',
          medicationStartDate: today,
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/medications/schedule',
      routes: [
        GoRoute(
          path: '/medications/schedule',
          builder: (context, state) =>
              MedicationScheduleScreen(repository: repository),
        ),
        GoRoute(
          path: '/medications/detail',
          builder: (context, state) => MedicationDetailScreen(
            medicationId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
            repository: repository,
          ),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await repository.close();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jour'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2 prises'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2 prises'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('18:00'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Traitement timeline'), findsNWidgets(2));
    expect(find.text('500 mg'), findsNWidgets(2));
    expect(find.text('Pris'), findsNWidgets(2));
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Traitement timeline').first);
    await tester.tap(find.text('Traitement timeline').first);
    await tester.pumpAndSettle();
    expect(find.text('Détail du traitement'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar fits the mobile viewport without layout overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryMedicationRepository(
      Medication(
        id: 10,
        name: 'Traitement mobile',
        dosage: '1 comprimé',
        time: '08:00',
        startDate: DateTime.now(),
        reminderEnabled: false,
      ),
    );
    final router = GoRouter(
      initialLocation: '/medications/schedule',
      routes: [
        GoRoute(
          path: '/medications/schedule',
          builder: (context, state) =>
              MedicationScheduleScreen(repository: repository),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await repository.close();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(GridView), findsOneWidget);

    await tester.tap(find.text('Semaine'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard keeps ended treatments available in history', (
    tester,
  ) async {
    final repository = _MemoryMedicationRepository(
      Medication(
        id: 3,
        name: 'Traitement actif',
        dosage: '1 comprimé',
        time: '08:00',
        startDate: DateTime.now().subtract(const Duration(days: 3)),
        endDate: DateTime.now().add(const Duration(days: 3)),
        reminderEnabled: true,
      ),
      additional: [
        Medication(
          id: 4,
          name: 'Traitement terminé',
          dosage: '2 comprimés',
          time: '20:00',
          startDate: DateTime.now().subtract(const Duration(days: 10)),
          endDate: DateTime.now().subtract(const Duration(days: 2)),
          reminderEnabled: false,
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/medications',
      routes: [
        GoRoute(
          path: '/medications',
          builder: (context, state) =>
              MedicationsDashboardScreen(repository: repository),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await repository.close();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Traitement actif'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Traitement terminé'), 100);
    await tester.pumpAndSettle();
    expect(find.text('Traitement terminé'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Terminés'), -100);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminés'));
    await tester.pumpAndSettle();
    expect(find.text('Traitements terminés'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Traitement terminé'), 100);
    await tester.pumpAndSettle();
    expect(find.text('Traitement terminé'), findsOneWidget);
    expect(find.text('Traitement actif'), findsNothing);
  });
}

class _MemoryMedicationRepository extends MedicationRepository {
  _MemoryMedicationRepository(
    Medication medication, {
    List<Medication> additional = const [],
    this._occurrences = const [],
  }) : _medications = [medication, ...additional];

  final List<Medication> _medications;
  final List<MedicationOccurrence> _occurrences;

  @override
  Future<List<Medication>> getAll() async => List.of(_medications);

  @override
  Future<Medication?> getById(int id) async {
    for (final medication in _medications) {
      if (medication.id == id) return medication;
    }
    return null;
  }

  @override
  Future<int> update(Medication medication) async {
    final index = _medications.indexWhere((item) => item.id == medication.id);
    if (index < 0) return 0;
    _medications[index] = medication;
    return 1;
  }

  @override
  Future<int> delete(int id) async {
    final previousLength = _medications.length;
    _medications.removeWhere((item) => item.id == id);
    return previousLength - _medications.length;
  }

  @override
  Future<int> ensureOccurrences({
    required DateTime from,
    required DateTime through,
  }) async => 0;

  @override
  Future<List<MedicationOccurrence>> getOccurrences({
    required DateTime from,
    required DateTime through,
  }) async => _occurrences
      .where(
        (occurrence) =>
            !DateUtils.dateOnly(occurrence.effectiveDate)
                .isBefore(DateUtils.dateOnly(from)) &&
            !DateUtils.dateOnly(occurrence.effectiveDate)
                .isAfter(DateUtils.dateOnly(through)),
      )
      .toList();

  @override
  Future<List<MedicationOccurrence>> getOccurrencesForMedication(
    int medicationId,
  ) async => const [];

  @override
  Future<void> close() async {}
}
