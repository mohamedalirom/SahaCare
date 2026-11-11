import 'helpers/medication_test_access.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test('SQLite statistics are read-only, include archived history and never backfill gaps', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sahacare_adherence_',
    );
    final file = '${directory.path}/medications.db';
    final repo = MedicationRepository(
      access: testMedicationAccess(),
      allowIsolatedMigration: true,
      databaseFactory: databaseFactoryFfi,
      databasePath: file,
    );
    addTearDown(repo.close);
    final start = DateTime(2026, 10, 25);
    final id = await repo.create(
      Medication(
        name: 'Historique fictif',
        dosage: '1 comprimé',
        time: '08:00',
        startDate: start,
        endDate: DateTime(2026, 10, 27),
        reminderEnabled: false,
      ),
    );
    // Seed only a single day; missing days must remain absent.
    await repo.ensureOccurrences(from: start, through: start);
    final occurrence = (await repo.getOccurrencesForMedication(id)).single;
    await repo.markOccurrenceTaken(occurrence.id);
    await repo.delete(id);
    final db = await databaseFactoryFfi.openDatabase(file);
    final tables = [
      'medications',
      'medication_schedules',
      'medication_schedule_times',
      'medication_occurrences',
      'medication_notification_registry',
      'medication_stock',
      'medication_stock_movements',
    ];
    final before = {for (final table in tables) table: await db.query(table)};
    final records = await repo.getAdherenceRecords(
      from: start,
      through: DateTime(2026, 10, 31),
    );
    expect(records.length, 1);
    expect(records.single.archivedAt, isNotNull);
    expect(records.single.occurrence.id, occurrence.id);
    expect(records.single.occurrence.confirmedAt, isNotNull);
    for (final table in tables) {
      expect(await db.query(table), before[table], reason: table);
    }
    expect(await db.getVersion(), 7);
  });
  test(
    'SQLite range uses effective date once and retains original scheduled time',
    () async {
      final repo = MedicationRepository(
        access: testMedicationAccess(),
        allowIsolatedMigration: true,
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(repo.close);
      final start = DateTime(2026, 10, 24);
      final id = await repo.create(
        Medication(
          name: 'Report fictif',
          dosage: '500 mg',
          time: '08:00',
          startDate: start,
          reminderEnabled: false,
        ),
      );
      await repo.ensureOccurrences(from: start, through: start);
      final o = (await repo.getOccurrencesForMedication(id)).single;
      await repo.postponeOccurrence(
        occurrenceId: o.id,
        date: DateTime(2026, 10, 26),
        time: '14:30',
      );
      expect(
        await repo.getAdherenceRecords(from: start, through: start),
        isEmpty,
      );
      final records = await repo.getAdherenceRecords(
        from: DateTime(2026, 10, 25),
        through: DateTime(2026, 10, 31),
      );
      expect(records.length, 1);
      expect(records.single.effectiveAt, DateTime(2026, 10, 26, 14, 30));
      expect(records.single.plannedAt, DateTime(2026, 10, 24, 8));
    },
  );
}
