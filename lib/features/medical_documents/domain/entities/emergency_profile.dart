import 'emergency_contact.dart';

/// Informations vitales affichées sur la carte d'urgence et le QR code (données fictives)
class EmergencyProfile {
  final String fullName;
  final DateTime birthDate;
  final String bloodGroup;
  final List<String> allergies;
  final List<String> conditions;
  final List<String> medications;
  final EmergencyContact contact;
  final DateTime updatedAt;

  const EmergencyProfile({
    required this.fullName,
    required this.birthDate,
    required this.bloodGroup,
    required this.allergies,
    required this.conditions,
    required this.medications,
    required this.contact,
    required this.updatedAt,
  });

  int get age {
    final now = DateTime.now();
    final hadBirthday =
        now.month > birthDate.month || (now.month == birthDate.month && now.day >= birthDate.day);
    return now.year - birthDate.year - (hadBirthday ? 0 : 1);
  }

  static const List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  static final EmergencyProfile mock = EmergencyProfile(
    fullName: 'Mohamed Ali Trabelsi',
    birthDate: DateTime(1994, 3, 12),
    bloodGroup: 'A+',
    allergies: const ['Pénicilline', 'Arachides'],
    conditions: const ['Asthme', 'Diabète de type 2'],
    medications: const ['Metformine 850 mg', 'Ventoline 100 µg (si crise)'],
    contact: EmergencyContact.mockContacts.first,
    updatedAt: DateTime(2026, 10, 2),
  );
}
