import '../entities/medication_occurrence.dart';

enum AdherenceStatus {
  confirmed('Confirmées'),
  missed('Manquées'),
  ignored('Ignorées'),
  postponed('Reportées'),
  late('En retard'),
  pending('En attente'),
  future('À venir');

  const AdherenceStatus(this.label);
  final String label;
}

/// SQLite snapshot, including archive metadata, without generating occurrences.
class AdherenceRecord {
  const AdherenceRecord(this.occurrence, {this.archivedAt});
  final MedicationOccurrence occurrence;
  final DateTime? archivedAt;
  DateTime get plannedAt =>
      _at(occurrence.scheduledDate, occurrence.scheduledTime);
  DateTime get effectiveAt =>
      _at(occurrence.effectiveDate, occurrence.effectiveTime);
  static DateTime _at(DateTime date, String time) {
    final parts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}

class AdherenceEntry {
  const AdherenceEntry(
    this.record,
    this.status, {
    this.confirmedLate = false,
    this.postponedOverdue = false,
  });
  final AdherenceRecord record;
  final AdherenceStatus status;
  final bool confirmedLate;
  final bool postponedOverdue;
  bool get eligible => status != AdherenceStatus.future;
}

class AdherenceSummary {
  AdherenceSummary(this.entries);
  final List<AdherenceEntry> entries;
  int count(AdherenceStatus status) =>
      entries.where((e) => e.status == status).length;
  int get denominator => entries.where((e) => e.eligible).length;
  int get confirmed => count(AdherenceStatus.confirmed);
  double? get percentage =>
      denominator == 0 ? null : 100 * confirmed / denominator;
}

class AdherenceDay extends AdherenceSummary {
  AdherenceDay(this.date, super.entries);
  final DateTime date;
}

class AdherenceMedication extends AdherenceSummary {
  AdherenceMedication(
    this.id,
    this.name,
    this.archived,
    this.completed,
    super.entries,
  );
  final int id;
  final String name;
  final bool archived;
  final bool completed;
}

class AdherenceReport extends AdherenceSummary {
  AdherenceReport({
    required this.now,
    required this.from,
    required this.days,
    required this.daily,
    required this.medications,
    required List<AdherenceEntry> entries,
  }) : super(entries);
  final DateTime now;
  final DateTime from;
  final int days;
  final List<AdherenceDay> daily;
  final List<AdherenceMedication> medications;
}

class MedicationAdherenceCalculator {
  static const lateAfter = Duration(minutes: 60);
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  AdherenceReport calculate(
    List<AdherenceRecord> records, {
    required int days,
    required DateTime now,
  }) {
    if (days != 7 && days != 30) {
      throw ArgumentError('Période attendue : 7 ou 30 jours.');
    }
    final localNow = now.toLocal();
    final today = dateOnly(localNow);
    // Calendar arithmetic, never 24-hour subtraction across DST transitions.
    final from = DateTime(today.year, today.month, today.day - days + 1);
    final until = DateTime(today.year, today.month, today.day + 1);
    return _calculate(
      records,
      from: from,
      until: until,
      days: days,
      now: localNow,
    );
  }

  /// Reuses the dashboard rules for an explicit local calendar range.
  AdherenceReport calculateRange(
    List<AdherenceRecord> records, {
    required DateTime from,
    required DateTime through,
    required DateTime now,
  }) {
    final first = dateOnly(from.toLocal());
    final last = dateOnly(through.toLocal());
    if (last.isBefore(first) || last.isAfter(dateOnly(now.toLocal()))) {
      throw ArgumentError('Choisissez une période passée ou en cours.');
    }
    var days = 0;
    var cursor = first;
    while (!cursor.isAfter(last)) {
      if (++days > 366) {
        throw ArgumentError('La période est limitée à 366 jours.');
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return _calculate(
      records,
      from: first,
      until: cursor,
      days: days,
      now: now.toLocal(),
    );
  }

  AdherenceReport _calculate(
    List<AdherenceRecord> records, {
    required DateTime from,
    required DateTime until,
    required int days,
    required DateTime now,
  }) {
    final localNow = now.toLocal();
    final today = dateOnly(localNow);
    final entries = <AdherenceEntry>[];
    final seen = <int>{};
    for (final record in records) {
      final o = record.occurrence;
      final due = record.effectiveAt;
      if (due.isBefore(from) || !due.isBefore(until)) continue;
      if (dateOnly(due).isBefore(dateOnly(o.medicationStartDate))) continue;
      if (o.medicationEndDate != null &&
          dateOnly(due).isAfter(dateOnly(o.medicationEndDate!))) {
        continue;
      }
      final archived = record.archivedAt?.toLocal();
      // Ignore unfulfilled obligations after archiving, retain actual decisions.
      if (archived != null &&
          due.isAfter(archived) &&
          (o.status == MedicationOccurrenceStatus.scheduled ||
              o.status == MedicationOccurrenceStatus.postponed)) {
        continue;
      }
      if (!seen.add(o.id)) continue;
      final future = due.isAfter(localNow);
      final delayed = localNow.difference(due) >= lateAfter;
      final status = future
          ? AdherenceStatus.future
          : switch (o.status) {
              MedicationOccurrenceStatus.taken => AdherenceStatus.confirmed,
              MedicationOccurrenceStatus.ignored => AdherenceStatus.ignored,
              MedicationOccurrenceStatus.postponed => AdherenceStatus.postponed,
              MedicationOccurrenceStatus.scheduled =>
                due.isBefore(today)
                    ? AdherenceStatus.missed
                    : delayed
                    ? AdherenceStatus.late
                    : AdherenceStatus.pending,
            };
      final actual = o.confirmedAt?.toLocal();
      entries.add(
        AdherenceEntry(
          record,
          status,
          confirmedLate:
              o.status == MedicationOccurrenceStatus.taken &&
              actual != null &&
              actual.difference(due) >= lateAfter,
          postponedOverdue:
              o.status == MedicationOccurrenceStatus.postponed &&
              !future &&
              delayed,
        ),
      );
    }
    entries.sort((a, b) {
      final date = b.record.effectiveAt.compareTo(a.record.effectiveAt);
      return date != 0
          ? date
          : a.record.occurrence.id.compareTo(b.record.occurrence.id);
    });
    final daily = List.generate(days, (index) {
      final day = DateTime(from.year, from.month, from.day + index);
      return AdherenceDay(
        day,
        entries.where((e) => dateOnly(e.record.effectiveAt) == day).toList(),
      );
    });
    final groups = <int, List<AdherenceEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(e.record.occurrence.medicationId, () => []).add(e);
    }
    final medications =
        groups.entries.map((g) {
          final first = g.value.first.record;
          final end = first.occurrence.medicationEndDate;
          return AdherenceMedication(
            g.key,
            first.occurrence.medicationName,
            first.archivedAt != null,
            end != null && dateOnly(end).isBefore(today),
            g.value,
          );
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    return AdherenceReport(
      now: localNow,
      from: from,
      days: days,
      daily: daily,
      medications: medications,
      entries: entries,
    );
  }
}
