import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/domain/entities/medication_occurrence.dart';
import 'package:sahacare/features/medications/domain/services/medication_adherence.dart';

AdherenceRecord record(
  int id,
  DateTime day, {
  String time = '08:00',
  MedicationOccurrenceStatus status = MedicationOccurrenceStatus.scheduled,
  DateTime? moved,
  String? movedTime,
  DateTime? actual,
  DateTime? archived,
  DateTime? end,
  int medicationId = 1,
  DateTime? start,
}) => AdherenceRecord(
  MedicationOccurrence(
    id: id,
    medicationId: medicationId,
    scheduleId: medicationId,
    scheduledDate: day,
    scheduledTime: time,
    status: status,
    medicationName: 'Médicament $medicationId',
    dosage: '500 mg',
    medicationStartDate: start ?? DateTime(2020),
    medicationEndDate: end,
    rescheduledDate: moved,
    rescheduledTime: movedTime,
    confirmedAt: actual,
  ),
  archivedAt: archived,
);

void main() {
  final now = DateTime(2026, 10, 31, 12);
  final today = DateTime(2026, 10, 31);
  final calculator = MedicationAdherenceCalculator();
  AdherenceReport report(
    List<AdherenceRecord> rows, {
    int days = 7,
    DateTime? at,
  }) => calculator.calculate(rows, days: days, now: at ?? now);

  test(
    'empty data has no fabricated percentage, with seven nullable daily points',
    () {
      final r = report([]);
      expect(r.percentage, isNull);
      expect(r.denominator, 0);
      expect(r.daily.length, 7);
      expect(r.daily.every((d) => d.percentage == null), isTrue);
    },
  );
  test('exclusive categories partition only due records and exact percentage is retained', () {
    final r = report([
      record(1, today, status: MedicationOccurrenceStatus.taken),
      record(2, DateTime(2026, 10, 30)),
      record(3, today, status: MedicationOccurrenceStatus.ignored),
      record(
        4,
        today,
        status: MedicationOccurrenceStatus.postponed,
        moved: today,
        movedTime: '09:00',
      ),
      record(5, today, time: '10:00'),
      record(6, today, time: '11:30'),
      record(7, today, time: '13:00'),
    ]);
    expect(r.denominator, 6);
    expect(r.percentage, closeTo(100 / 6, .00001));
    for (final s in AdherenceStatus.values) {
      expect(r.count(s), 1, reason: s.name);
    }
  });
  test('future ignored or early-confirmed intakes are never missed or included in denominator', () {
    final r = report([
      record(1, today, time: '13:00'),
      record(
        2,
        today,
        time: '14:00',
        status: MedicationOccurrenceStatus.taken,
        actual: now,
      ),
      record(
        3,
        today,
        time: '15:00',
        status: MedicationOccurrenceStatus.ignored,
      ),
    ]);
    expect(r.count(AdherenceStatus.future), 3);
    expect(r.percentage, isNull);
    expect(r.count(AdherenceStatus.missed), 0);
    expect(report([record(1, today, time: '12:00')]).denominator, 1);
  });
  test('late threshold is exactly sixty minutes, pending before, missed next local day', () {
    final dose = record(1, today, time: '11:00');
    expect(
      report([
        dose,
      ], at: DateTime(2026, 10, 31, 11, 59, 59)).count(AdherenceStatus.pending),
      1,
    );
    expect(report([dose]).count(AdherenceStatus.late), 1);
    expect(
      report([
        record(2, DateTime(2026, 10, 30), time: '23:50'),
      ], at: DateTime(2026, 10, 31, 0, 10)).count(AdherenceStatus.missed),
      1,
    );
  });
  test('late confirmations remain confirmed once, missing actual time is not invented', () {
    final r = report([
      record(
        1,
        today,
        status: MedicationOccurrenceStatus.taken,
        actual: DateTime(2026, 10, 31, 9).toUtc(),
      ),
      record(2, today, status: MedicationOccurrenceStatus.taken),
      record(
        3,
        today,
        status: MedicationOccurrenceStatus.taken,
        actual: DateTime(2026, 10, 31, 8, 59, 59),
      ),
    ]);
    expect(r.confirmed, 3);
    expect(r.percentage, 100);
    expect(r.count(AdherenceStatus.late), 0);
    expect(r.entries.where((e) => e.confirmedLate).length, 1);
    expect(
      r.entries
          .singleWhere((e) => e.record.occurrence.id == 2)
          .record
          .occurrence
          .confirmedAt,
      isNull,
    );
  });
  test('postponed overdue remains postponed and duplicate snapshots never double count', () {
    final dose = record(
      1,
      DateTime(2026, 10, 24),
      status: MedicationOccurrenceStatus.postponed,
      moved: DateTime(2026, 10, 30),
      movedTime: '20:00',
    );
    final r = report([dose, dose]);
    expect(r.denominator, 1);
    expect(r.count(AdherenceStatus.postponed), 1);
    expect(r.entries.single.postponedOverdue, isTrue);
    expect(r.count(AdherenceStatus.missed), 0);
    expect(
      r.daily.singleWhere((d) => d.date == DateTime(2026, 10, 30)).denominator,
      1,
    );
  });
  test(
    'moving outside period excludes original date; future report is not missed',
    () {
      expect(
        report([
          record(
            1,
            today,
            status: MedicationOccurrenceStatus.postponed,
            moved: DateTime(2026, 11, 1),
            movedTime: '08:00',
          ),
        ]).entries,
        isEmpty,
      );
      final r = report([
        record(
          2,
          DateTime(2026, 10, 30),
          status: MedicationOccurrenceStatus.postponed,
          moved: today,
          movedTime: '18:00',
        ),
      ]);
      expect(r.denominator, 0);
      expect(r.count(AdherenceStatus.future), 1);
    },
  );
  for (final days in [7, 30]) {
    test(
      '$days local calendar days include first midnight and today but exclude adjacent dates',
      () {
        final first = DateTime(2026, 10, 31 - days + 1);
        final r = report([
          record(1, first, time: '00:00'),
          record(
            2,
            DateTime(first.year, first.month, first.day - 1),
            time: '23:59',
          ),
          record(3, today),
          record(4, DateTime(2026, 11, 1)),
        ], days: days);
        expect(r.from, first);
        expect(r.daily.length, days);
        expect(r.entries.length, 2);
        expect(r.daily.last.date, today);
      },
    );
  }
  test(
    'calendar days remain contiguous across daylight saving transitions',
    () {
      for (final date in [
        DateTime(2026, 3, 31, 12),
        DateTime(2026, 10, 31, 12),
      ]) {
        final r = report([], days: 30, at: date);
        expect(
          r.daily
              .map((d) => '${d.date.year}-${d.date.month}-${d.date.day}')
              .toSet()
              .length,
          30,
        );
        expect(r.from, DateTime(date.year, date.month, date.day - 29));
        expect(r.daily.every((d) => d.date.hour == 0), isTrue);
      }
    },
  );
  test('archived past records remain but unfulfilled obligations after archive are excluded', () {
    final archive = DateTime(2026, 10, 30, 12);
    final r = report([
      record(1, DateTime(2026, 10, 30), archived: archive),
      record(2, today, archived: archive),
      record(
        3,
        today,
        status: MedicationOccurrenceStatus.postponed,
        archived: archive,
      ),
      record(
        4,
        today,
        status: MedicationOccurrenceStatus.taken,
        archived: archive,
      ),
    ]);
    expect(r.entries.length, 2);
    expect(r.medications.single.archived, isTrue);
    expect(r.confirmed, 1);
  });
  test('completed medication retains valid history without obligations beyond end or before start', () {
    final end = DateTime(2026, 10, 30);
    final r = report([
      record(1, end, end: end),
      record(2, today, end: end),
      record(3, DateTime(2026, 10, 29), start: end, end: end),
    ]);
    expect(r.entries.length, 1);
    expect(r.medications.single.completed, isTrue);
  });
  test('medication identities are separate and daily denominators aggregate correctly', () {
    final r = report([
      record(1, today, status: MedicationOccurrenceStatus.taken),
      record(2, today, medicationId: 2),
      record(
        3,
        DateTime(2026, 10, 30),
        status: MedicationOccurrenceStatus.taken,
      ),
    ]);
    expect(r.medications.length, 2);
    expect(r.medications.first.percentage, 100);
    expect(r.daily.last.percentage, 50);
    expect(r.percentage, closeTo(200 / 3, .0001));
  });
  test(
    'unsupported periods fail explicitly',
    () => expect(() => report([], days: 14), throwsArgumentError),
  );
}
