import 'medication_access.dart';
import '../../domain/entities/medication_report.dart';
import '../../domain/services/medication_adherence.dart';
import '../medication_repository.dart';
import 'medication_report_pdf.dart';

typedef MedicationReportSessionReader = MedicationReportSession Function();

MedicationReportSession currentMedicationReportSession([
  MedicationAccess? access,
]) {
  try {
    final lease = (access ?? MedicationAccess.instance).capture();
    return MedicationReportSession(
      key: '${lease.owner}@${lease.generation}',
      localDemo: lease.demo,
      verified: true,
    );
  } on MedicationAccessDenied {
    return const MedicationReportSession(key: '', localDemo: false);
  }
}

class MedicationReportService {
  MedicationReportService({
    MedicationRepository? repository,
    MedicationReportSessionReader? sessionReader,
    MedicationReportPdf? pdf,
    DateTime Function()? clock,
  }) : repository = repository ?? MedicationRepository.instance,
       sessionReader =
           sessionReader ??
           (() => currentMedicationReportSession(
             (repository ?? MedicationRepository.instance).access,
           )),
       pdf = pdf ?? MedicationReportPdf(),
       clock = clock ?? DateTime.now;
  final MedicationRepository repository;
  final MedicationReportSessionReader sessionReader;
  final MedicationReportPdf pdf;
  final DateTime Function() clock;

  MedicationReportSession requireAccess({String? expectedKey}) {
    repository.access.capture().check();
    final session = sessionReader();
    if (!session.allowed ||
        (expectedKey != null && session.key != expectedKey)) {
      throw StateError(
        'Rapport bloqué : session absente, expirée ou modifiée.',
      );
    }
    return session;
  }

  Future<List<ReportTreatment>> choices() async {
    final lease = repository.access.capture();
    final session = requireAccess();
    final now = clock().toLocal();
    final snapshot = await repository.getReportSnapshot(
      from: now,
      through: now,
    );
    lease.check();
    requireAccess(expectedKey: session.key);
    return snapshot.treatments;
  }

  Future<MedicationReportData> collect(
    MedicationReportOptions options, {
    required bool acknowledgeAnonymous,
  }) async {
    final lease = repository.access.capture();
    final session = requireAccess();
    if (!acknowledgeAnonymous) {
      throw StateError(
        'Confirmez la vérification du contenu local et son export sans identité.',
      );
    }
    final now = clock().toLocal();
    final calculator = MedicationAdherenceCalculator();
    calculator.calculateRange(
      [],
      from: options.from,
      through: options.through,
      now: now,
    );
    final snapshot = await repository.getReportSnapshot(
      from: options.from,
      through: options.through,
    );
    lease.check();
    requireAccess(expectedKey: session.key);
    if (options.medicationId != null &&
        !snapshot.treatments.any(
          (t) => t.medication.id == options.medicationId,
        )) {
      throw StateError('Le médicament sélectionné n’est plus disponible.');
    }
    final treatments = snapshot.treatments.where((t) {
      final m = t.medication;
      return (options.medicationId == null || m.id == options.medicationId) &&
          (options.includeCompleted || !t.completedAt(now)) &&
          !MedicationAdherenceCalculator.dateOnly(m.startDate)
              .isAfter(options.through) &&
          (m.endDate == null ||
              !MedicationAdherenceCalculator.dateOnly(m.endDate!)
                  .isBefore(options.from)) &&
          (t.archivedAt == null ||
              !MedicationAdherenceCalculator.dateOnly(t.archivedAt!.toLocal())
                  .isBefore(options.from));
    }).toList();
    final ids = treatments.map((t) => t.medication.id).toSet();
    final rows = snapshot.occurrences
        .where((r) => ids.contains(r.occurrence.medicationId))
        .toList();
    if (treatments.length > 100 || rows.length > 2000) {
      throw StateError(
        'Rapport trop volumineux : réduisez la période ou sélectionnez un médicament (100 traitements et 2 000 prises maximum).',
      );
    }
    for (final t in treatments) {
      final m = t.medication;
      if ([
        m.name,
        m.dosage,
        m.activeIngredient ?? '',
        m.commercialPresentation ?? '',
      ].any((s) => s.length > 600)) {
        throw StateError(
          'Un champ de traitement dépasse 600 caractères. Corrigez ce champ avant l’export.',
        );
      }
    }
    return MedicationReportData(
      options: options,
      generatedAt: now,
      treatments: List.unmodifiable(treatments),
      adherence: calculator.calculateRange(
        rows,
        from: options.from,
        through: options.through,
        now: now,
      ),
    );
  }

  Future<MedicationReportArtifact> generate(
    MedicationReportOptions options, {
    required bool acknowledgeAnonymous,
  }) async {
    final lease = repository.access.capture();
    final session = requireAccess();
    final data = await collect(
      options,
      acknowledgeAnonymous: acknowledgeAnonymous,
    );
    final bytes = await pdf.build(data);
    lease.check();
    requireAccess(expectedKey: session.key);
    return MedicationReportArtifact(
      bytes: bytes,
      filename:
          'sahacare-traitements-${data.generatedAt.microsecondsSinceEpoch}.pdf',
      sessionKey: session.key,
      data: data,
      verifyAccess: () {
        lease.check();
        requireAccess(expectedKey: session.key);
      },
    );
  }
}
