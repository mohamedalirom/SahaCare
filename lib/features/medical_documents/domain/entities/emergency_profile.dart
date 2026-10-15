/// Informations vitales affichées sur la carte d'urgence et le QR code.
/// Le contact affiché est le contact d'urgence principal (voir EmergencyContactsNotifier).
class EmergencyProfile {
  final String fullName;
  final DateTime birthDate;
  final String bloodGroup;
  final List<String> allergies;
  final List<String> conditions;
  final List<String> medications;
  final DateTime updatedAt;

  const EmergencyProfile({
    required this.fullName,
    required this.birthDate,
    required this.bloodGroup,
    required this.allergies,
    required this.conditions,
    required this.medications,
    required this.updatedAt,
  });

  int get age {
    final now = DateTime.now();
    final hadBirthday =
        now.month > birthDate.month || (now.month == birthDate.month && now.day >= birthDate.day);
    return now.year - birthDate.year - (hadBirthday ? 0 : 1);
  }

  EmergencyProfile copyWith({
    String? bloodGroup,
    List<String>? allergies,
    List<String>? conditions,
    List<String>? medications,
    DateTime? updatedAt,
  }) {
    return EmergencyProfile(
      fullName: fullName,
      birthDate: birthDate,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      medications: medications ?? this.medications,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  static final EmergencyProfile mock = EmergencyProfile(
    fullName: 'Mohamed Ali Trabelsi',
    birthDate: DateTime(1994, 3, 12),
    bloodGroup: 'A+',
    allergies: const ['Pénicilline', 'Arachides'],
    conditions: const ['Asthme', 'Diabète de type 2'],
    medications: const ['Metformine 850 mg', 'Ventoline 100 µg (si crise)'],
    updatedAt: DateTime(2026, 10, 2),
  );
}
