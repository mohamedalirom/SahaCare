import 'helpers/medication_test_access.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test(
    'report snapshot includes archived medication and is entirely read only',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sahacare_report_',
      );
      final file = '${directory.path}/report.db';
      final repo = MedicationRepository(
        access: testMedicationAccess(),
        allowIsolatedMigration: true,
        databaseFactory: databaseFactoryFfi,
        databasePath: file,
      );
      addTearDown(repo.close);
      final day = DateTime(2026, 10, 25);
      final id = await repo.create(
        Medication(
          name: 'Fictif archivé',
          dosage: '1 unité',
          time: '08:00',
          startDate: day,
          reminderEnabled: false,
        ),
      );
      await repo.ensureOccurrences(from: day, through: day);
      await repo.markOccurrenceTaken(
        (await repo.getOccurrencesForMedication(id)).single.id,
      );
      await repo.delete(id);
      final db = await databaseFactoryFfi.openDatabase(file);
      final tables = [
        'medications',
        'medication_schedules',
        'medication_schedule_times',
        'medication_occurrences',
        'medication_stock',
        'medication_stock_movements',
        'medication_notification_registry',
      ];
      final before = {for (final table in tables) table: await db.query(table)};
      final snapshot = await repo.getReportSnapshot(
        from: day,
        through: DateTime(2026, 10, 31),
      );
      expect(snapshot.treatments.single.archivedAt, isNotNull);
      expect(snapshot.occurrences.length, 1);
      for (final table in tables) {
        expect(await db.query(table), before[table], reason: table);
      }
      expect(await db.getVersion(), 7);
    },
  );
}
