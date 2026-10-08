/// Contact à prévenir en cas d'urgence (données fictives)
class EmergencyContact {
  final String id;
  final String name;
  final String relation;
  final String phone;
  final String? email;
  final bool isPrimary;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
    this.email,
    this.isPrimary = false,
  });

  /// Initiales affichées dans l'avatar (ex : "Amira Trabelsi" → "AT")
  String get initials {
    final parts = name.replaceAll('Dr. ', '').split(' ').where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  /// Relations proposées dans le formulaire
  static const List<String> relations = [
    'Conjoint(e)',
    'Père',
    'Mère',
    'Frère',
    'Sœur',
    'Enfant',
    'Ami(e)',
    'Médecin traitant',
    'Autre',
  ];

  static const List<EmergencyContact> mockContacts = [
    EmergencyContact(
      id: 'c1',
      name: 'Amira Trabelsi',
      relation: 'Conjoint(e)',
      phone: '+216 22 345 678',
      email: 'amira.trabelsi@email.tn',
      isPrimary: true,
    ),
    EmergencyContact(
      id: 'c2',
      name: 'Fatma Trabelsi',
      relation: 'Mère',
      phone: '+216 98 765 432',
      email: 'fatma.trabelsi@email.tn',
    ),
    EmergencyContact(
      id: 'c3',
      name: 'Dr. Karim Haddad',
      relation: 'Médecin traitant',
      phone: '+216 71 234 567',
      email: 'cabinet.haddad@email.tn',
    ),
  ];
}
