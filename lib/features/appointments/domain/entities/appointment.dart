/// Statut d'un rendez-vous médical
enum AppointmentStatus {
  upcoming, // À venir
  completed, // Effectué / Passé
  cancelled, // Annulé
}

extension AppointmentStatusExt on AppointmentStatus {
  String get label {
    switch (this) {
      case AppointmentStatus.upcoming:
        return 'À venir';
      case AppointmentStatus.completed:
        return 'Effectué';
      case AppointmentStatus.cancelled:
        return 'Annulé';
    }
  }
}

/// Type de rappel / notification avant le rendez-vous
enum ReminderOption {
  oneHourBefore,
  twoHoursBefore,
  oneDayBefore,
  twoDaysBefore,
  none,
}

extension ReminderOptionExt on ReminderOption {
  String get label {
    switch (this) {
      case ReminderOption.oneHourBefore:
        return '1 heure avant';
      case ReminderOption.twoHoursBefore:
        return '2 heures avant';
      case ReminderOption.oneDayBefore:
        return '24 heures (1 jour) avant';
      case ReminderOption.twoDaysBefore:
        return '48 heures (2 jours) avant';
      case ReminderOption.none:
        return 'Aucun rappel';
    }
  }
}

/// Entité représentant un rendez-vous médical
class Appointment {
  final String id;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String doctorAddress;
  final String doctorPhone;
  final DateTime dateTime;
  final String timeSlot; // ex: "10:30"
  final String reason; // Motif de consultation
  final AppointmentStatus status;
  final ReminderOption reminder;
  final bool notificationEnabled;
  final String? notes;
  final double fee;

  const Appointment({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.doctorAddress,
    required this.doctorPhone,
    required this.dateTime,
    required this.timeSlot,
    required this.reason,
    required this.status,
    this.reminder = ReminderOption.oneDayBefore,
    this.notificationEnabled = true,
    this.notes,
    this.fee = 60.0,
  });

  /// Rendez-vous de démonstration
  static List<Appointment> get mockAppointments => [
        Appointment(
          id: 'apt-1',
          doctorId: 'doc-1',
          doctorName: 'Dr. Karim Mansour',
          doctorSpecialty: 'Cardiologie',
          doctorAddress: 'Avenue Habib Bourguiba, Tunis',
          doctorPhone: '+216 71 234 567',
          dateTime: DateTime.now().add(const Duration(days: 2, hours: 3)),
          timeSlot: '10:30',
          reason: 'Contrôle annuel de tension artérielle et électrocardiogramme',
          status: AppointmentStatus.upcoming,
          reminder: ReminderOption.oneDayBefore,
          notificationEnabled: true,
          notes: 'Apporter les résultats du dernier bilan sanguin.',
          fee: 70.0,
        ),
        Appointment(
          id: 'apt-2',
          doctorId: 'doc-2',
          doctorName: 'Dr. Sarah Ben Salem',
          doctorSpecialty: 'Médecine Générale',
          doctorAddress: 'Rue Ahmed Tlili, El Menzah 6',
          doctorPhone: '+216 71 890 123',
          dateTime: DateTime.now().add(const Duration(days: 7, hours: 5)),
          timeSlot: '14:30',
          reason: 'Renouvellement ordonnance et suivi régulier',
          status: AppointmentStatus.upcoming,
          reminder: ReminderOption.twoHoursBefore,
          notificationEnabled: true,
          notes: 'À jeun si possible pour prise de sang.',
          fee: 50.0,
        ),
        Appointment(
          id: 'apt-3',
          doctorId: 'doc-3',
          doctorName: 'Dr. Nadia Trabelsi',
          doctorSpecialty: 'Dermatologie',
          doctorAddress: 'Rue du Lac Léman, Berges du Lac 1',
          doctorPhone: '+216 70 456 789',
          dateTime: DateTime.now().subtract(const Duration(days: 15)),
          timeSlot: '11:00',
          reason: 'Contrôle cutané et traitement eczéma',
          status: AppointmentStatus.completed,
          reminder: ReminderOption.none,
          notificationEnabled: false,
          notes: 'Prescription crème hydratante délivrée.',
          fee: 65.0,
        ),
        Appointment(
          id: 'apt-4',
          doctorId: 'doc-4',
          doctorName: 'Dr. Youssef Chaabane',
          doctorSpecialty: 'Pédiatrie',
          doctorAddress: 'Avenue de la Liberté, Ariana',
          doctorPhone: '+216 71 999 888',
          dateTime: DateTime.now().subtract(const Duration(days: 40)),
          timeSlot: '09:30',
          reason: 'Vaccination rappel',
          status: AppointmentStatus.cancelled,
          reminder: ReminderOption.none,
          notificationEnabled: false,
          notes: 'Annulé pour empêchement professionnel.',
          fee: 60.0,
        ),
      ];
}
