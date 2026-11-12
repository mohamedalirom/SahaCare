import 'dart:async';
import 'dart:typed_data';

import 'helpers/medication_test_access.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/data/services/medication_report_pdf.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/data/services/medication_report_service.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/entities/medication_report.dart';
import 'package:sahacare/features/medications/domain/entities/medication_occurrence.dart';
import 'package:sahacare/features/medications/domain/services/medication_adherence.dart';

import 'medication_adherence_test.dart' show record;

class ReportMemoryRepository extends MedicationRepository {
  ReportMemoryRepository(this.snapshot) : super(access: testMedicationAccess());
  MedicationReportSnapshot snapshot;
  int reads = 0;
  Future<void> Function()? beforeReturn;
  @override
  Future<MedicationReportSnapshot> getReportSnapshot({
    required DateTime from,
    required DateTime through,
  }) async {
    reads++;
    await beforeReturn?.call();
    return snapshot;
  }
}

final reportNow = DateTime(2026, 10, 31, 12);
MedicationReportSession demoReportSession() =>
    const MedicationReportSession(key: 'local-demo-user', localDemo: true);
ReportTreatment reportTreatment({
  int id = 1,
  String name = 'Traitement fictif à libération prolongée',
  DateTime? end,
  DateTime? archive,
}) => ReportTreatment(
  Medication(
    id: id,
    name: name,
    dosage: '1 comprimé déclaré',
    time: '08:00',
    scheduleTimes: const ['08:00', '20:00'],
    weekdaysMask: 31,
    startDate: DateTime(2026, 9, 1),
    endDate: end,
    reminderEnabled: false,
    activeIngredient: 'Substance de test',
    commercialPresentation: 'Comprimé - échantillon fictif',
  ),
  archivedAt: archive,
);

MedicationReportSnapshot reportFixture() => MedicationReportSnapshot(
  treatments: [
    reportTreatment(),
    reportTreatment(id: 2, end: DateTime(2026, 10, 30)),
    reportTreatment(id: 3, archive: DateTime(2026, 10, 30, 12)),
  ],
  occurrences: [
    record(
      1,
      DateTime(2026, 10, 31),
      status: MedicationOccurrenceStatus.taken,
      actual: DateTime(2026, 10, 31, 8, 5),
    ),
    record(
      2,
      DateTime(2026, 10, 30),
      status: MedicationOccurrenceStatus.ignored,
    ),
    record(3, DateTime(2026, 10, 12)),
    record(
      4,
      DateTime(2026, 10, 30),
      medicationId: 2,
      status: MedicationOccurrenceStatus.taken,
    ),
    record(
      5,
      DateTime(2026, 10, 30),
      medicationId: 3,
      status: MedicationOccurrenceStatus.taken,
      archived: DateTime(2026, 10, 30, 12),
    ),
  ],
);

class _DelayedPdf extends MedicationReportPdf {
  final started = Completer<void>();
  final finished = Completer<Uint8List>();
  @override
  Future<Uint8List> build(MedicationReportData data) {
    started.complete();
    return finished.future;
  }
}

void main() {
  late ReportMemoryRepository repo;
  late MedicationReportService service;
  setUp(() {
    repo = ReportMemoryRepository(reportFixture());
    service = MedicationReportService(
      repository: repo,
      sessionReader: demoReportSession,
      clock: () => reportNow,
    );
  });
  MedicationReportOptions options(
    int days, {
    bool completed = false,
    int? id,
  }) => MedicationReportOptions(
    from: DateTime(2026, 10, 31 - days + 1),
    through: reportNow,
    includeCompleted: completed,
    medicationId: id,
  );

  test('real account and absent session are blocked before reading any local medical rows', () async {
    for (final session in [
      const MedicationReportSession(key: 'account-A', localDemo: false),
      const MedicationReportSession(key: '', localDemo: true),
      const MedicationReportSession(key: 'other', localDemo: true),
    ]) {
      final guarded = MedicationReportService(
        repository: repo,
        sessionReader: () => session,
      );
      await expectLater(
        guarded.collect(options(7), acknowledgeAnonymous: true),
        throwsStateError,
      );
      await expectLater(guarded.choices(), throwsStateError);
    }
    expect(repo.reads, 0);
  });
  test('explicit review of anonymous dataset is mandatory', () async {
    await expectLater(
      service.collect(options(7), acknowledgeAnonymous: false),
      throwsStateError,
    );
    expect(repo.reads, 0);
  });
  test('session changes during read cannot produce a report', () async {
    var session = demoReportSession();
    repo.beforeReturn = () async {
      session = const MedicationReportSession(
        key: 'account-B',
        localDemo: false,
      );
    };
    final guarded = MedicationReportService(
      repository: repo,
      sessionReader: () => session,
      clock: () => reportNow,
    );
    await expectLater(
      guarded.collect(options(7), acknowledgeAnonymous: true),
      throwsStateError,
    );
    expect(repo.reads, 1);
  });
  test(
    'session changes during PDF rendering discard bytes before delivery',
    () async {
      var session = demoReportSession();
      final pdf = _DelayedPdf();
      final guarded = MedicationReportService(
        repository: repo,
        sessionReader: () => session,
        pdf: pdf,
        clock: () => reportNow,
      );
      final future = guarded.generate(options(7), acknowledgeAnonymous: true);
      await pdf.started.future;
      session = const MedicationReportSession(
        key: 'other-account',
        localDemo: false,
      );
      final expectation = expectLater(future, throwsStateError);
      pdf.finished.complete(Uint8List.fromList([37, 80, 68, 70, 45]));
      await expectation;
    },
  );
  for (final days in [7, 30]) {
    test(
      '$days day report preserves dashboard percentages and denominators',
      () async {
        final data = await service.collect(
          options(days),
          acknowledgeAnonymous: true,
        );
        final expected = MedicationAdherenceCalculator().calculate(
          repo.snapshot.occurrences
              .where((r) => r.occurrence.medicationId == 1)
              .toList(),
          days: days,
          now: reportNow,
        );
        expect(data.adherence.percentage, expected.percentage);
        expect(data.adherence.denominator, expected.denominator);
        for (final status in AdherenceStatus.values) {
          expect(data.adherence.count(status), expected.count(status));
        }
        expect(data.treatments.length, 1);
      },
    );
  }
  test('completed and archived data require opt in; medication filter never includes another ID', () async {
    final data = await service.collect(
      options(7, completed: true),
      acknowledgeAnonymous: true,
    );
    expect(data.treatments.length, 3);
    expect(data.adherence.denominator, 4);
    final only = await service.collect(
      options(7, completed: true, id: 2),
      acknowledgeAnonymous: true,
    );
    expect(only.treatments.single.medication.id, 2);
    expect(only.adherence.entries.single.record.occurrence.medicationId, 2);
    await expectLater(
      service.collect(options(7, id: 999), acknowledgeAnonymous: true),
      throwsStateError,
    );
  });
  test('custom period uses same rules for past dates and no future intakes are invented', () async {
    final data = await service.collect(
      MedicationReportOptions(
        from: DateTime(2026, 9, 1),
        through: DateTime(2026, 10, 12),
      ),
      acknowledgeAnonymous: true,
    );
    expect(data.adherence.days, 42);
    expect(data.adherence.entries.length, 1);
    expect(data.adherence.count(AdherenceStatus.missed), 1);
    expect(data.adherence.percentage, 0);
  });
  test(
    'future, reversed and overlong periods are rejected before database reads',
    () async {
      for (final dates in [
        (DateTime(2026, 10, 31), DateTime(2026, 11, 1)),
        (DateTime(2026, 10, 31), DateTime(2026, 10, 30)),
        (DateTime(2020), reportNow),
      ]) {
        await expectLater(
          service.collect(
            MedicationReportOptions(from: dates.$1, through: dates.$2),
            acknowledgeAnonymous: true,
          ),
          throwsArgumentError,
        );
      }
      expect(repo.reads, 0);
    },
  );
  test(
    'empty report remains empty and identity/symptoms are never synthesized',
    () async {
      repo.snapshot = const MedicationReportSnapshot(
        treatments: [],
        occurrences: [],
      );
      final data = await service.collect(
        options(7),
        acknowledgeAnonymous: true,
      );
      expect(data.adherence.percentage, isNull);
      expect(data.treatments, isEmpty);
      expect(
        MedicationReportData.privacyNotice,
        contains('Aucun patient identifié'),
      );
      expect(
        MedicationReportData.symptomsNotice,
        contains('Aucun symptôme enregistré dans ce rapport'),
      );
    },
  );
  test(
    'oversized reports fail instead of silently truncating medical data',
    () async {
      repo.snapshot = MedicationReportSnapshot(
        treatments: [reportTreatment()],
        occurrences: [
          for (var i = 0; i < 2001; i++) record(i, DateTime(2026, 10, 31)),
        ],
      );
      await expectLater(
        service.collect(options(7), acknowledgeAnonymous: true),
        throwsStateError,
      );
    },
  );
}
