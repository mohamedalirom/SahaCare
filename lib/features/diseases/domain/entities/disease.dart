/// Entité représentant une maladie ou affection médicale
class Disease {
  final String id;
  final String name;
  final String category; // ex: Chronique, Respiratoire, Cardiovasculaire, Métabolique
  final DateTime diagnosedDate;
  final DiseaseSeverity severity; // mild, moderate, severe
  final DiseaseStatus status; // active, inTreatment, recovered, chronic
  final String treatingDoctor;
  final String description;
  final List<String> symptoms;
  final List<String> treatments;
  final String? notes;

  const Disease({
    required this.id,
    required this.name,
    required this.category,
    required this.diagnosedDate,
    required this.severity,
    required this.status,
    required this.treatingDoctor,
    required this.description,
    this.symptoms = const [],
    this.treatments = const [],
    this.notes,
  });

  /// Données de démonstration pour alimenter les interfaces
  static List<Disease> get mockDiseases => [
        Disease(
          id: '1',
          name: 'Diabète de Type 2',
          category: 'Métabolique & Endocrinien',
          diagnosedDate: DateTime(2023, 4, 15),
          severity: DiseaseSeverity.moderate,
          status: DiseaseStatus.chronic,
          treatingDoctor: 'Dr. Sarah Ben Salem (Endocrinologue)',
          description:
              'Trouble métabolique caractérisé par une glycémie élevée chronique due à une résistance à l\'insuline.',
          symptoms: ['Fatigue fréquente', 'Soif accrue', 'Vision floue occasionnelle'],
          treatments: ['Metformine 500mg', 'Régime pauvre en sucres rapides', 'Activité physique 3x/semaine'],
          notes: 'Contrôle HbA1c tous les 3 mois. Prochain bilan prévu le mois prochain.',
        ),
        Disease(
          id: '2',
          name: 'Hypertension Artérielle',
          category: 'Cardiovasculaire',
          diagnosedDate: DateTime(2022, 10, 5),
          severity: DiseaseSeverity.moderate,
          status: DiseaseStatus.active,
          treatingDoctor: 'Dr. Karim Mansour (Cardiologue)',
          description:
              'Pression anormalement élevée du sang contre les parois des artères.',
          symptoms: ['Maux de tête matinaux', 'Vertiges légers lors de l\'effort'],
          treatments: ['Amlodipine 5mg (1x/jour le matin)', 'Réduction du sel alimentaire'],
          notes: 'Tension moyenne stable à 130/85 mmHg.',
        ),
        Disease(
          id: '3',
          name: 'Asthme Allergique',
          category: 'Respiratoire',
          diagnosedDate: DateTime(2021, 6, 20),
          severity: DiseaseSeverity.mild,
          status: DiseaseStatus.inTreatment,
          treatingDoctor: 'Dr. Nadia Trabelsi (Pneumologue)',
          description:
              'Inflammation chronique des voies respiratoires déclenchée par des allergènes (pollen, acariens).',
          symptoms: ['Toux sèche nocturne', 'Essoufflement en présence de poussière'],
          treatments: ['Ventoline (en cas de crise)', 'Corticoïde inhalé quotidien'],
          notes: 'Pics de crise observés surtout au printemps.',
        ),
      ];
}

enum DiseaseSeverity {
  mild,
  moderate,
  severe,
}

enum DiseaseStatus {
  active,
  inTreatment,
  recovered,
  chronic,
}

extension DiseaseSeverityExt on DiseaseSeverity {
  String get label {
    switch (this) {
      case DiseaseSeverity.mild:
        return 'Légère';
      case DiseaseSeverity.moderate:
        return 'Modérée';
      case DiseaseSeverity.severe:
        return 'Sévère';
    }
  }
}

extension DiseaseStatusExt on DiseaseStatus {
  String get label {
    switch (this) {
      case DiseaseStatus.active:
        return 'Actif';
      case DiseaseStatus.inTreatment:
        return 'En traitement';
      case DiseaseStatus.recovered:
        return 'Guérie';
      case DiseaseStatus.chronic:
        return 'Chronique';
    }
  }
}
