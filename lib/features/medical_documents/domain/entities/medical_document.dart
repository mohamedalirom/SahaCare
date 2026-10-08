import 'package:flutter/material.dart';

/// Catégories de documents médicaux gérées par le module
enum DocumentCategory {
  prescription, // Ordonnance
  analysis, // Analyse
  report, // Rapport médical
}

extension DocumentCategoryExt on DocumentCategory {
  String get label {
    switch (this) {
      case DocumentCategory.prescription:
        return 'Ordonnance';
      case DocumentCategory.analysis:
        return 'Analyse';
      case DocumentCategory.report:
        return 'Rapport médical';
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentCategory.prescription:
        return Icons.receipt_long_rounded;
      case DocumentCategory.analysis:
        return Icons.biotech_rounded;
      case DocumentCategory.report:
        return Icons.description_rounded;
    }
  }

  Color get color {
    switch (this) {
      case DocumentCategory.prescription:
        return const Color(0xFF0D9488);
      case DocumentCategory.analysis:
        return const Color(0xFF0284C7);
      case DocumentCategory.report:
        return const Color(0xFF10B981);
    }
  }

  /// Libellé de l'auteur du document (médecin ou laboratoire)
  String get authorLabel => this == DocumentCategory.analysis ? 'Laboratoire' : 'Médecin';

  IconData get authorIcon =>
      this == DocumentCategory.analysis ? Icons.apartment_rounded : Icons.person_rounded;

  /// Libellé du champ texte libre du document
  String get noteLabel => this == DocumentCategory.analysis ? 'Résultat / remarque' : 'Description';
}

/// Document médical (ordonnance, analyse ou rapport).
/// Données fictives uniquement : aucune persistance pour le moment.
class MedicalDocument {
  final String id;
  final DocumentCategory category;
  final String title; // Titre, ou type d'analyse
  final String author; // Médecin ou laboratoire
  final DateTime date;
  final String? note;
  final String? fileName;

  const MedicalDocument({
    required this.id,
    required this.category,
    required this.title,
    required this.author,
    required this.date,
    this.note,
    this.fileName,
  });

  static final List<MedicalDocument> mockPrescriptions = [
    MedicalDocument(
      id: 'p1',
      category: DocumentCategory.prescription,
      title: 'Traitement hypertension',
      author: 'Dr. Sarra Ben Ali',
      date: DateTime(2026, 9, 28),
      note: 'Amlodipine 5 mg — 1 comprimé le matin pendant 3 mois.',
      fileName: 'ordonnance_cardio.pdf',
    ),
    MedicalDocument(
      id: 'p2',
      category: DocumentCategory.prescription,
      title: 'Antibiotique angine',
      author: 'Dr. Karim Haddad',
      date: DateTime(2026, 8, 14),
      note: 'Amoxicilline 1 g — 2 fois par jour pendant 7 jours.',
      fileName: 'ordonnance_angine.pdf',
    ),
    MedicalDocument(
      id: 'p3',
      category: DocumentCategory.prescription,
      title: 'Renouvellement traitement diabète',
      author: 'Dr. Leila Mansour',
      date: DateTime(2026, 6, 3),
      note: 'Metformine 850 mg — matin et soir, au cours du repas.',
      fileName: 'ordonnance_diabete.jpg',
    ),
    MedicalDocument(
      id: 'p4',
      category: DocumentCategory.prescription,
      title: 'Collyre allergie saisonnière',
      author: 'Dr. Youssef Gharbi',
      date: DateTime(2026, 4, 21),
      note: '1 goutte dans chaque œil, 2 fois par jour pendant 15 jours.',
    ),
  ];

  static final List<MedicalDocument> mockAnalyses = [
    MedicalDocument(
      id: 'a1',
      category: DocumentCategory.analysis,
      title: 'Bilan sanguin complet',
      author: 'Laboratoire Pasteur',
      date: DateTime(2026, 9, 30),
      note: 'Résultats normaux. Légère carence en vitamine D.',
      fileName: 'bilan_sanguin.pdf',
    ),
    MedicalDocument(
      id: 'a2',
      category: DocumentCategory.analysis,
      title: 'Hémoglobine glyquée (HbA1c)',
      author: 'Laboratoire BioSanté',
      date: DateTime(2026, 8, 2),
      note: 'HbA1c : 6,4 % — à surveiller.',
      fileName: 'hba1c.pdf',
    ),
    MedicalDocument(
      id: 'a3',
      category: DocumentCategory.analysis,
      title: 'Bilan lipidique',
      author: 'Laboratoire Pasteur',
      date: DateTime(2026, 5, 17),
      note: 'Cholestérol LDL : 1,35 g/L.',
      fileName: 'bilan_lipidique.pdf',
    ),
    MedicalDocument(
      id: 'a4',
      category: DocumentCategory.analysis,
      title: 'Analyse d\'urine (ECBU)',
      author: 'Laboratoire Central',
      date: DateTime(2026, 2, 9),
      note: 'Aucune infection détectée.',
    ),
  ];

  static final List<MedicalDocument> mockReports = [
    MedicalDocument(
      id: 'r1',
      category: DocumentCategory.report,
      title: 'Compte rendu échographie cardiaque',
      author: 'Dr. Sarra Ben Ali',
      date: DateTime(2026, 9, 28),
      note: 'Fonction ventriculaire normale, pas d\'anomalie valvulaire.',
      fileName: 'echo_cardiaque.pdf',
    ),
    MedicalDocument(
      id: 'r2',
      category: DocumentCategory.report,
      title: 'Compte rendu d\'hospitalisation',
      author: 'Dr. Nabil Jaziri',
      date: DateTime(2026, 3, 11),
      note: 'Hospitalisation de 3 jours pour crise d\'asthme sévère. Sortie sous traitement de fond.',
      fileName: 'hospitalisation.pdf',
    ),
    MedicalDocument(
      id: 'r3',
      category: DocumentCategory.report,
      title: 'Radiographie thoracique',
      author: 'Dr. Ines Chaabane',
      date: DateTime(2025, 11, 25),
      note: 'Poumons clairs, pas d\'opacité suspecte.',
      fileName: 'radio_thorax.jpg',
    ),
  ];
}
