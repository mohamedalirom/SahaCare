import 'package:timezone/timezone.dart' as tz;

import '../entities/medication.dart';
import '../entities/medication_occurrence.dart';

class MedicationReminder {
  const MedicationReminder({required this.key, required this.at});

  final String key;
  final tz.TZDateTime at;

  // No medical details in the lock-screen message or notification payload.
  String get signature => '${at.millisecondsSinceEpoch}|${at.location.name}|v1';
  String get payload => 'sahacare.medication:$key|$signature';
}

class MedicationReminderPlan {
  const MedicationReminderPlan(this.reminders, this.truncated);
  final List<MedicationReminder> reminders;
  final bool truncated;
}

/// Pure calendar calculation. No database, plugin or permission access.
class MedicationReminderPlanner {
  const MedicationReminderPlanner();

  MedicationReminderPlan calculate({
    required List<Medication> medications,
    required List<MedicationOccurrence> occurrences,
    required tz.Location location,
    required DateTime now,
    int horizonDays = 28,
    int limit = 60,
  }) {
    final localNow = tz.TZDateTime.from(now, location);
    final first = DateTime.utc(localNow.year, localNow.month, localNow.day);
    final last = first.add(Duration(days: horizonDays));
    final result = <String, MedicationReminder>{};
    final enabled = {
      for (final medication in medications)
        if (medication.id != null && medication.reminderEnabled)
          medication.id!: medication,
    };
    String key(int id, DateTime date, String time) =>
        '$id/${date.year}-${date.month}-${date.day}/$time';

    MedicationReminder? reminder(
      Medication medication,
      DateTime date,
      String time,
      String identity,
    ) {
      final day = DateTime.utc(date.year, date.month, date.day);
      if (day.isBefore(first) ||
          day.isAfter(last) ||
          !medication.isActiveOn(day)) {
        return null;
      }
      final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
      if (match == null) return null;
      final hour = int.parse(match[1]!);
      final minute = int.parse(match[2]!);
      if (hour > 23 || minute > 59) return null;
      final at = _wallTime(location, day, hour, minute);
      if (!at.isAfter(localNow)) return null;
      return MedicationReminder(key: identity, at: at);
    }

    for (final medication in enabled.values) {
      final times = medication.scheduleTimes.isEmpty
          ? [medication.time]
          : medication.scheduleTimes;
      for (
        var day = first;
        !day.isAfter(last);
        day = day.add(const Duration(days: 1))
      ) {
        if (medication.weekdaysMask & (1 << (day.weekday - 1)) == 0) continue;
        for (final time in times) {
          final identity = key(medication.id!, day, time);
          final item = reminder(medication, day, time, identity);
          if (item != null) result[identity] = item;
        }
      }
    }
    for (final occurrence in occurrences) {
      final medication = enabled[occurrence.medicationId];
      if (medication == null) continue;
      final identity = key(
        occurrence.medicationId,
        occurrence.scheduledDate,
        occurrence.scheduledTime,
      );
      switch (occurrence.status) {
        case MedicationOccurrenceStatus.taken:
        case MedicationOccurrenceStatus.ignored:
          result.remove(identity);
        case MedicationOccurrenceStatus.postponed:
          result.remove(identity);
          final item = reminder(
            medication,
            occurrence.effectiveDate,
            occurrence.effectiveTime,
            identity,
          );
          if (item != null) result[identity] = item;
        case MedicationOccurrenceStatus.scheduled:
          // Only the current schedule creates ordinary future occurrences.
          break;
      }
    }
    final sorted = result.values.toList()
      ..sort((a, b) {
        final dateOrder = a.at.compareTo(b.at);
        return dateOrder == 0 ? a.key.compareTo(b.key) : dateOrder;
      });
    return MedicationReminderPlan(
      sorted.take(limit).toList(),
      sorted.length > limit,
    );
  }

  /// On a DST gap, use the first valid local minute after the requested time.
  /// A repeated local hour produces only one notification per occurrence key.
  tz.TZDateTime _wallTime(tz.Location location, DateTime day, int h, int m) {
    var wall = DateTime.utc(day.year, day.month, day.day, h, m);
    for (var i = 0; i < 180; i++) {
      final candidate = tz.TZDateTime(
        location,
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
      );
      if (candidate.year == wall.year &&
          candidate.month == wall.month &&
          candidate.day == wall.day &&
          candidate.hour == wall.hour &&
          candidate.minute == wall.minute) {
        return candidate;
      }
      wall = wall.add(const Duration(minutes: 1));
    }
    throw StateError('Impossible de résoudre cet horaire dans ce fuseau.');
  }
}
