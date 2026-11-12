import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/entities/medication_occurrence.dart';
import 'package:sahacare/features/medications/domain/services/medication_reminder_planner.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(data.initializeTimeZones);
  const planner = MedicationReminderPlanner();
  final now = DateTime.utc(2030, 1, 7, 6);

  Medication medication({
    bool enabled = true,
    int weekdays = 127,
    DateTime? start,
    DateTime? end,
    List<String> times = const ['09:00', '18:00'],
  }) => Medication(
    id: 1,
    name: 'Traitement',
    dosage: 'Prescription',
    time: times.first,
    scheduleTimes: times,
    startDate: start ?? DateTime(2030, 1, 7),
    endDate: end,
    weekdaysMask: weekdays,
    reminderEnabled: enabled,
  );

  MedicationOccurrence occurrence(
    MedicationOccurrenceStatus status, {
    DateTime? date,
    String time = '09:00',
    DateTime? postponedDate,
    String? postponedTime,
  }) => MedicationOccurrence(
    id: 1,
    medicationId: 1,
    scheduleId: 1,
    scheduledDate: date ?? DateTime(2030, 1, 7),
    scheduledTime: time,
    status: status,
    medicationName: 'Traitement',
    dosage: 'Prescription',
    medicationStartDate: DateTime(2030, 1, 7),
    rescheduledDate: postponedDate,
    rescheduledTime: postponedTime,
  );

  MedicationReminderPlan calculate(
    Medication m, {
    List<MedicationOccurrence> overrides = const [],
    int limit = 60,
    String zone = 'Europe/Paris',
    DateTime? instant,
    int days = 2,
  }) => planner.calculate(
    medications: [m],
    occurrences: overrides,
    location: tz.getLocation(zone),
    now: instant ?? now,
    limit: limit,
    horizonDays: days,
  );

  test('uses selected weekdays and multiple times within inclusive dates', () {
    final plan = calculate(
      medication(
        weekdays: 1 | 4,
        start: DateTime(2030, 1, 8),
        end: DateTime(2030, 1, 9),
      ),
    );
    expect(plan.reminders.map((e) => e.at.day), [9, 9]);
    expect(plan.reminders.map((e) => e.at.hour), [9, 18]);
  });

  test('disabled, ended and not-yet-started treatments have no reminders', () {
    expect(calculate(medication(enabled: false)).reminders, isEmpty);
    expect(calculate(medication(end: DateTime(2030, 1, 6))).reminders, isEmpty);
    expect(
      calculate(medication(start: DateTime(2030, 2, 1))).reminders,
      isEmpty,
    );
  });

  test('never schedules an elapsed or exactly current instant', () {
    final plan = calculate(medication(), instant: DateTime.utc(2030, 1, 7, 8));
    expect(plan.reminders.first.at.hour, 18);
    expect(
      plan.reminders.every((e) => e.at.isAfter(DateTime.utc(2030, 1, 7, 8))),
      isTrue,
    );
  });

  test('confirmation and ignored doses suppress only their original keys', () {
    for (final status in [
      MedicationOccurrenceStatus.taken,
      MedicationOccurrenceStatus.ignored,
    ]) {
      final plan = calculate(medication(), overrides: [occurrence(status)]);
      expect(plan.reminders.length, 5);
      expect(plan.reminders.first.at.hour, 18);
    }
  });

  test(
    'postponement replaces original time while preserving stable identity',
    () {
      final original = calculate(medication()).reminders.first;
      final plan = calculate(
        medication(),
        overrides: [
          occurrence(
            MedicationOccurrenceStatus.postponed,
            postponedDate: DateTime(2030, 1, 8),
            postponedTime: '11:00',
          ),
        ],
      );
      final moved = plan.reminders.singleWhere((e) => e.key == original.key);
      expect(moved.at.day, 8);
      expect(moved.at.hour, 11);
      expect(plan.reminders.length, 6);
      expect(plan.reminders.where((e) => e.key == original.key).length, 1);
    },
  );

  test('postponed dose whose original day is past is still included', () {
    final plan = calculate(
      medication(start: DateTime(2030, 1, 1)),
      overrides: [
        occurrence(
          MedicationOccurrenceStatus.postponed,
          date: DateTime(2030, 1, 6),
          postponedDate: DateTime(2030, 1, 7),
          postponedTime: '11:00',
        ),
      ],
    );
    expect(plan.reminders.any((e) => e.at.hour == 11), isTrue);
  });

  test('postponements outside new treatment dates are excluded', () {
    final plan = calculate(
      medication(end: DateTime(2030, 1, 7)),
      overrides: [
        occurrence(
          MedicationOccurrenceStatus.postponed,
          postponedDate: DateTime(2030, 1, 8),
          postponedTime: '11:00',
        ),
      ],
    );
    expect(plan.reminders.length, 1);
    expect(plan.reminders.single.at.hour, 18);
  });

  test(
    'zone changes preserve wall time but change UTC instant and signature',
    () {
      final paris = calculate(medication()).reminders.first;
      final newYork = calculate(
        medication(),
        zone: 'America/New_York',
      ).reminders.first;
      expect(paris.at.hour, 9);
      expect(newYork.at.hour, 9);
      expect(paris.key, newYork.key);
      expect(paris.signature, isNot(newYork.signature));
    },
  );

  test('spring DST gap moves reminder to first existing minute', () {
    final plan = calculate(
      medication(
        start: DateTime(2030, 3, 31),
        end: DateTime(2030, 3, 31),
        times: ['02:30'],
      ),
      instant: DateTime.utc(2030, 3, 30),
      days: 2,
    );
    expect(plan.reminders.single.at.hour, 3);
    expect(plan.reminders.single.at.minute, 0);
  });

  test('autumn DST repeated hour produces one reminder only', () {
    final plan = calculate(
      medication(
        start: DateTime(2030, 10, 27),
        end: DateTime(2030, 10, 27),
        times: ['02:30'],
      ),
      instant: DateTime.utc(2030, 10, 26),
      days: 2,
    );
    expect(plan.reminders.length, 1);
    expect(plan.reminders.single.at.hour, 2);
  });

  test(
    'deduplicates repeated schedule entries and respects global capacity',
    () {
      final plan = calculate(medication(times: ['09:00', '09:00']), limit: 2);
      expect(plan.reminders.length, 2);
      expect(plan.truncated, isTrue);
      expect(plan.reminders.map((e) => e.key).toSet().length, 2);
      expect(calculate(medication(), limit: 0).reminders, isEmpty);
    },
  );
}
