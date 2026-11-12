enum MedicationOccurrenceStatus { scheduled, taken, postponed, ignored }

class MedicationOccurrence {
  const MedicationOccurrence({
    required this.id,
    required this.medicationId,
    required this.scheduleId,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    required this.medicationName,
    required this.dosage,
    required this.medicationStartDate,
    this.medicationEndDate,
    this.activeIngredient,
    this.rescheduledDate,
    this.rescheduledTime,
    this.confirmedAt,
  });

  final int id;
  final int medicationId;
  final int scheduleId;
  final DateTime scheduledDate;
  final String scheduledTime;
  final MedicationOccurrenceStatus status;
  final String medicationName;
  final String dosage;
  final DateTime medicationStartDate;
  final DateTime? medicationEndDate;
  final String? activeIngredient;
  final DateTime? rescheduledDate;
  final String? rescheduledTime;
  final DateTime? confirmedAt;

  DateTime get effectiveDate => rescheduledDate ?? scheduledDate;
  String get effectiveTime => rescheduledTime ?? scheduledTime;

  String statusLabel({DateTime? now}) {
    return switch (status) {
      MedicationOccurrenceStatus.scheduled =>
        _isInFuture(now ?? DateTime.now())
            ? 'À venir'
            : 'En attente de confirmation',
      MedicationOccurrenceStatus.taken => 'Pris',
      MedicationOccurrenceStatus.postponed => 'Reporté',
      MedicationOccurrenceStatus.ignored => 'Ignoré',
    };
  }

  bool _isInFuture(DateTime now) {
    final parts = scheduledTime.split(':');
    if (parts.length != 2) return false;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return false;
    }
    final scheduledAt = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      hour,
      minute,
    );
    return scheduledAt.isAfter(now);
  }

  factory MedicationOccurrence.fromMap(Map<String, Object?> map) {
    return MedicationOccurrence(
      id: map['id'] as int,
      medicationId: map['medication_id'] as int,
      scheduleId: map['schedule_id'] as int,
      scheduledDate: DateTime.parse(map['scheduled_date'] as String),
      scheduledTime: map['scheduled_time'] as String,
      status: switch (map['status']) {
        'scheduled' => MedicationOccurrenceStatus.scheduled,
        'taken' => MedicationOccurrenceStatus.taken,
        'postponed' => MedicationOccurrenceStatus.postponed,
        'ignored' => MedicationOccurrenceStatus.ignored,
        final value => throw FormatException(
          'Invalid medication occurrence status: $value',
        ),
      },
      medicationName: map['medication_name'] as String,
      dosage: map['medication_dosage'] as String,
      medicationStartDate: DateTime.parse(
        map['medication_start_date'] as String,
      ),
      medicationEndDate: map['medication_end_date'] == null
          ? null
          : DateTime.parse(map['medication_end_date'] as String),
      activeIngredient: map['medication_active_ingredient'] as String?,
      rescheduledDate: map['rescheduled_date'] == null
          ? null
          : DateTime.parse(map['rescheduled_date'] as String),
      rescheduledTime: map['rescheduled_time'] as String?,
      confirmedAt: map['confirmed_at'] == null
          ? null
          : DateTime.parse(map['confirmed_at'] as String),
    );
  }
}
