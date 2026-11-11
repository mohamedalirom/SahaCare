import 'dart:typed_data';

import 'medication.dart';
import '../services/medication_adherence.dart';

class MedicationReportOptions {
  MedicationReportOptions({
    required DateTime from,
    required DateTime through,
    this.medicationId,
    this.includeCompleted = false,
    this.includeAdherence = true,
    this.includeHistory = true,
    this.includeSymptoms = true,
  }) : from = MedicationAdherenceCalculator.dateOnly(from.toLocal()),
       through = MedicationAdherenceCalculator.dateOnly(through.toLocal());
  final DateTime from;
  final DateTime through;
  final int? medicationId;
  final bool includeCompleted;
  final bool includeAdherence;
  final bool includeHistory;
  final bool includeSymptoms;
}

class ReportTreatment {
  const ReportTreatment(this.medication, {this.archivedAt});
  final Medication medication;
  final DateTime? archivedAt;
  bool completedAt(DateTime now) =>
      archivedAt != null ||
      (medication.endDate != null &&
          MedicationAdherenceCalculator.dateOnly(medication.endDate!)
              .isBefore(MedicationAdherenceCalculator.dateOnly(now)));
}

class MedicationReportSnapshot {
  const MedicationReportSnapshot({
    required this.treatments,
    required this.occurrences,
  });
  final List<ReportTreatment> treatments;
  final List<AdherenceRecord> occurrences;
}

class MedicationReportSession {
  const MedicationReportSession({
    required this.key,
    required this.localDemo,
    this.verified = false,
  });
  final String key;
  final bool localDemo;
  final bool verified;
  bool get allowed => verified || (localDemo && key == 'local-demo-user');
}

class MedicationReportData {
  const MedicationReportData({
    required this.options,
    required this.generatedAt,
    required this.treatments,
    required this.adherence,
  });
  final MedicationReportOptions options;
  final DateTime generatedAt;
  final List<ReportTreatment> treatments;
  final AdherenceReport adherence;
  // No patient identity or unscoped symptom text can enter this model.
  static const privacyNotice =
      'Rapport du compte courant. Aucun patient identifié dans ce document. '
      'Vérifiez les informations enregistrées avant tout partage.';
  static const symptomsNotice =
      'Aucun symptôme enregistré dans ce rapport. '
      'L’historique d’orientation existant ne possède pas de propriétaire identifiable ; '
      'il n’a pas été importé pour éviter de mélanger les données de plusieurs personnes.';
  static const footer =
      'Rapport généré par SahaCare à partir des informations enregistrées par l’utilisateur. '
      'Ce document ne remplace pas un avis médical.';
}

class MedicationReportArtifact {
  const MedicationReportArtifact({
    required this.bytes,
    required this.filename,
    required this.sessionKey,
    required this.data,
    this.verifyAccess,
  });
  final Uint8List bytes;
  final String filename;
  final String sessionKey;
  final MedicationReportData data;
  final void Function()? verifyAccess;
  void assertCurrent() {
    if (verifyAccess == null) {
      throw StateError('Rapport sans autorisation de session.');
    }
    verifyAccess!();
  }
}
