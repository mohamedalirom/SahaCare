class Medication {
  const Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.startDate,
    required this.endDate,
    required this.reminderEnabled,
  });

  final int? id;
  final String name;
  final String dosage;
  final String time;
  final DateTime startDate;
  final DateTime endDate;
  final bool reminderEnabled;

  Medication copyWith({
    int? id,
    String? name,
    String? dosage,
    String? time,
    DateTime? startDate,
    DateTime? endDate,
    bool? reminderEnabled,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      time: time ?? this.time,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'time': time,
      'start_date': _dateToDatabase(startDate),
      'end_date': _dateToDatabase(endDate),
      'reminder_enabled': reminderEnabled ? 1 : 0,
    };
  }

  factory Medication.fromMap(Map<String, Object?> map) {
    return Medication(
      id: map['id'] as int,
      name: map['name'] as String,
      dosage: map['dosage'] as String,
      time: map['time'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      reminderEnabled: map['reminder_enabled'] == 1,
    );
  }

  static String _dateToDatabase(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
