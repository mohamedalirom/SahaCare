import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication_occurrence.dart';
import 'package:sahacare/features/medications/presentation/screens/medication_schedule_screen.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_calendar_widgets.dart';

import 'helpers/medication_test_access.dart';

MedicationOccurrence dose(int id) => MedicationOccurrence(
  id: id,
  medicationId: id,
  scheduleId: id,
  scheduledDate: DateUtils.dateOnly(DateTime.now()),
  scheduledTime: '08:00',
  status: MedicationOccurrenceStatus.scheduled,
  medicationName: 'Traitement fictif au nom volontairement détaillé $id',
  dosage: 'Dose déclarée de test, sans recommandation médicale',
  medicationStartDate: DateTime(2026),
);

class CalendarRepository extends MedicationRepository {
  CalendarRepository(this.count) : super(access: testMedicationAccess());
  final int count;
  @override
  Future<int> ensureOccurrences({
    required DateTime from,
    required DateTime through,
  }) async => 0;
  @override
  Future<List<MedicationOccurrence>> getOccurrences({
    required DateTime from,
    required DateTime through,
  }) async => List.generate(count, dose);
}

void main() {
  testWidgets('week respects phone constraints inside a desktop MediaQuery', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 380,
              child: MedicationWeekSelector(
                weekStart: DateTime(2026, 11, 9),
                selectedDate: DateTime(2026, 11, 10),
                occurrences: [],
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getRect(find.text('DIM')).right,
      lessThanOrEqualTo(
        tester.getRect(find.byType(MedicationWeekSelector)).right,
      ),
    );
    expect(tester.takeException(), isNull);
  });
  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(412, 860),
    Size(440, 956),
  ]) {
    for (final count in [0, 1, 4]) {
      testWidgets('calendar all views at $size with $count occurrences', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = CalendarRepository(count);
        addTearDown(repo.access.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: MedicationScheduleScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MedicationMonthCalendar), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final view in ['Jour', 'Semaine', 'Mois']) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(find.text(view));
          await tester.pumpAndSettle();
          expect(
            find.byType(MedicationWeekSelector),
            view == 'Semaine' ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(MedicationMonthCalendar),
            view == 'Mois' ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byType(MedicationDailyTimeline),
            220,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          if (count == 0) {
            expect(
              find.text('Aucune prise prévue pour cette journée.'),
              findsOneWidget,
            );
          } else {
            expect(find.text(dose(0).medicationName), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('timeline retains its explicit action callbacks', (tester) async {
    var taken = 0, postponed = 0, ignored = 0, opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MedicationDailyTimeline(
              occurrences: [dose(0)],
              busyOccurrenceIds: {},
              onOpen: (_) => opened++,
              onTaken: (_) => taken++,
              onPostpone: (_) => postponed++,
              onIgnore: (_) => ignored++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pris'));
    await tester.tap(find.text('Reporter'));
    await tester.tap(find.text('Ignorer'));
    await tester.tap(find.text(dose(0).medicationName));
    expect([taken, postponed, ignored, opened], [1, 1, 1, 1]);
    expect(tester.takeException(), isNull);
  });
}
