/// Spécialités médicales disponibles
class Specialty {
  final String id;
  final String name;
  final String iconName;
  final int doctorsCount;

  const Specialty({
    required this.id,
    required this.name,
    required this.iconName,
    required this.doctorsCount,
  });

  static List<Specialty> get mockSpecialties => const [
        Specialty(id: 'all', name: 'Toutes', iconName: 'local_hospital', doctorsCount: 12),
        Specialty(id: 'cardio', name: 'Cardiologie', iconName: 'favorite', doctorsCount: 4),
        Specialty(id: 'general', name: 'Médecine Générale', iconName: 'medical_services', doctorsCount: 5),
        Specialty(id: 'derma', name: 'Dermatologie', iconName: 'clean_hands', doctorsCount: 2),
        Specialty(id: 'pediatry', name: 'Pédiatrie', iconName: 'child_care', doctorsCount: 3),
        Specialty(id: 'ophtalmo', name: 'Ophtalmologie', iconName: 'visibility', doctorsCount: 2),
        Specialty(id: 'dentist', name: 'Dentiste', iconName: 'mood', doctorsCount: 3),
      ];
}

/// Entité représentant un médecin
class Doctor {
  final String id;
  final String fullName;
  final String specialty;
  final String hospitalOrClinic;
  final String address;
  final String phone;
  final String email;
  final double rating;
  final int reviewsCount;
  final double consultationFee; // en DT ou devise locale
  final String bio;
  final List<String> availableDays;
  final List<String> availableSlots;

  const Doctor({
    required this.id,
    required this.fullName,
    required this.specialty,
    required this.hospitalOrClinic,
    required this.address,
    required this.phone,
    required this.email,
    required this.rating,
    required this.reviewsCount,
    required this.consultationFee,
    required this.bio,
    this.availableDays = const ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'],
    this.availableSlots = const [
      '09:00',
      '09:30',
      '10:00',
      '10:30',
      '11:00',
      '14:00',
      '14:30',
      '15:00',
      '15:30',
      '16:00',
      '16:30',
    ],
  });

  static List<Doctor> get mockDoctors => const [
        Doctor(
          id: 'doc-1',
          fullName: 'Dr. Karim Mansour',
          specialty: 'Cardiologie',
          hospitalOrClinic: 'Clinique du Cœur & Vaisseaux',
          address: 'Avenue Habib Bourguiba, Tunis',
          phone: '+216 71 234 567',
          email: 'dr.karim.mansour@sahacare.tn',
          rating: 4.9,
          reviewsCount: 124,
          consultationFee: 70.0,
          bio:
              'Spécialiste des pathologies cardiovasculaires, suivi de l\'hypertension, échographie cardiaque et bilan préventif.',
        ),
        Doctor(
          id: 'doc-2',
          fullName: 'Dr. Sarah Ben Salem',
          specialty: 'Médecine Générale',
          hospitalOrClinic: 'Cabinet Médical El Menzah',
          address: 'Rue Ahmed Tlili, El Menzah 6',
          phone: '+216 71 890 123',
          email: 'dr.sarah.bensalem@sahacare.tn',
          rating: 4.8,
          reviewsCount: 98,
          consultationFee: 50.0,
          bio:
              'Médecin de famille dévoué, diagnostic complet, suivi des maladies chroniques, bilan de santé et orientation médicale.',
        ),
        Doctor(
          id: 'doc-3',
          fullName: 'Dr. Nadia Trabelsi',
          specialty: 'Dermatologie',
          hospitalOrClinic: 'Centre Médical Les Berges du Lac',
          address: 'Rue du Lac Léman, Berges du Lac 1',
          phone: '+216 70 456 789',
          email: 'dr.nadia.trabelsi@sahacare.tn',
          rating: 4.7,
          reviewsCount: 86,
          consultationFee: 65.0,
          bio:
              'Dermatologue et vénérologue, traitement des allergies cutanées, acné, psoriasis, surveillance des grains de beauté.',
        ),
        Doctor(
          id: 'doc-4',
          fullName: 'Dr. Youssef Chaabane',
          specialty: 'Pédiatrie',
          hospitalOrClinic: 'Clinique Pédiatrique de l\'Espoir',
          address: 'Avenue de la Liberté, Ariana',
          phone: '+216 71 999 888',
          email: 'dr.youssef.chaabane@sahacare.tn',
          rating: 4.9,
          reviewsCount: 152,
          consultationFee: 60.0,
          bio:
              'Spécialiste de la santé de l\'enfant et du nourrisson, suivi de croissance, vaccinations et urgences pédiatriques courantes.',
        ),
      ];
}
