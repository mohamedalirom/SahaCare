import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/data/services/medication_report_pdf.dart';
import 'package:sahacare/features/medications/data/services/medication_report_service.dart';
import 'package:sahacare/features/medications/domain/entities/medication_occurrence.dart';
import 'package:sahacare/features/medications/domain/entities/medication_report.dart';

import 'medication_report_test.dart'
    show
        reportFixture,
        reportNow,
        reportTreatment,
        ReportMemoryRepository,
        demoReportSession;
import 'medication_adherence_test.dart' show record;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generate valid empty PDF with embedded local French fonts', () async {
    final repo = ReportMemoryRepository(
      const MedicationReportSnapshot(treatments: [], occurrences: []),
    );
    final service = MedicationReportService(
      repository: repo,
      sessionReader: demoReportSession,
      clock: () => reportNow,
    );
    final artifact = await service.generate(
      MedicationReportOptions(from: DateTime(2026, 10, 25), through: reportNow),
      acknowledgeAnonymous: true,
    );
    expect(utf8.decode(artifact.bytes.take(5).toList()), '%PDF-');
    expect(artifact.bytes.length, greaterThan(10000));
    await Directory('build/pdf-report-validation').create(recursive: true);
    await File('build/pdf-report-validation/empty.pdf')
        .writeAsBytes(artifact.bytes);
  });
  test(
    'French accents and multi-page table preserve every history row',
    () async {
      final fixture = reportFixture();
      final repo = ReportMemoryRepository(
        MedicationReportSnapshot(
          treatments: [
            ...fixture.treatments,
            reportTreatment(
              id: 4,
              name: 'Traitement fictif - cœur, fièvre, œdème, Élévation',
            ),
          ],
          occurrences: [
            ...fixture.occurrences,
            for (var i = 0; i < 140; i++)
              record(
                100 + i,
                DateTime(2026, 10, 2 + i % 30),
                medicationId: 4,
                time: i.isEven ? '08:00' : '20:00',
                status: MedicationOccurrenceStatus.taken,
                actual: DateTime(2026, 10, 2 + i % 30, 8, 15),
              ),
          ],
        ),
      );
      final service = MedicationReportService(
        repository: repo,
        sessionReader: demoReportSession,
        pdf: MedicationReportPdf(),
        clock: () => reportNow,
      );
      final artifact = await service.generate(
        MedicationReportOptions(
          from: DateTime(2026, 10, 2),
          through: reportNow,
          includeCompleted: true,
        ),
        acknowledgeAnonymous: true,
      );
      expect(artifact.data.adherence.entries.length, 145);
      final raw = latin1.decode(artifact.bytes);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(raw).length, greaterThan(3));
      await Directory('build/pdf-report-validation').create(recursive: true);
      await File('build/pdf-report-validation/multipage.pdf')
          .writeAsBytes(artifact.bytes);
    },
  );
  test(
    'seven day PDF omits optional sections without altering observance',
    () async {
      final service = MedicationReportService(
        repository: ReportMemoryRepository(reportFixture()),
        sessionReader: demoReportSession,
        clock: () => reportNow,
      );
      final artifact = await service.generate(
        MedicationReportOptions(
          from: DateTime(2026, 10, 25),
          through: reportNow,
          includeHistory: false,
          includeSymptoms: false,
          includeAdherence: false,
        ),
        acknowledgeAnonymous: true,
      );
      expect(artifact.data.adherence.denominator, 2);
      await Directory('build/pdf-report-validation').create(recursive: true);
      await File('build/pdf-report-validation/minimal.pdf')
          .writeAsBytes(artifact.bytes);
    },
  );
}
