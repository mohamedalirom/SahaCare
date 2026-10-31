class Medication {
  const Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.startDate,
    this.endDate,
    required this.reminderEnabled,
    this.activeIngredient,
    this.commercialPresentation,
    this.scheduleTimes = const [],
    this.weekdaysMask = 127,
  });

  final int? id;
  final String name;
  final String dosage;
  final String time;
  final DateTime startDate;
  final DateTime? endDate;
  final bool reminderEnabled;
  final String? activeIngredient;
  final String? commercialPresentation;
  final List<String> scheduleTimes;
  final int weekdaysMask;

  bool isActiveOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = endDate == null
        ? null
        : DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !day.isBefore(start) && (end == null || !day.isAfter(end));
  }

  Medication copyWith({
    int? id,
    String? name,
    String? dosage,
    String? time,
    List<String>? scheduleTimes,
    int? weekdaysMask,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? reminderEnabled,
    String? activeIngredient,
    String? commercialPresentation,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      time: time ?? this.time,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      weekdaysMask: weekdaysMask ?? this.weekdaysMask,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      activeIngredient: activeIngredient ?? this.activeIngredient,
      commercialPresentation:
          commercialPresentation ?? this.commercialPresentation,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'time': time,
      'start_date': _dateToDatabase(startDate),
      'end_date': endDate == null ? null : _dateToDatabase(endDate!),
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'active_ingredient': activeIngredient,
      'commercial_presentation': commercialPresentation,
    };
  }

  factory Medication.fromMap(Map<String, Object?> map) {
    return Medication(
      id: map['id'] as int,
      name: map['name'] as String,
      dosage: map['dosage'] as String,
      time: map['time'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] == null
          ? null
          : DateTime.parse(map['end_date'] as String),
      reminderEnabled: map['reminder_enabled'] == 1,
      activeIngredient: map['active_ingredient'] as String?,
      commercialPresentation: map['commercial_presentation'] as String?,
      scheduleTimes: (map['schedule_times'] as List<String>?) ?? const [],
      weekdaysMask: map['weekdays_mask'] as int? ?? 127,
    );
  }

  static String _dateToDatabase(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
