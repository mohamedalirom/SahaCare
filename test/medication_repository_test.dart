import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/entities/medication_occurrence.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'supports medication create, read, update and delete in SQLite',
    () async {
      final repository = MedicationRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(repository.close);

      final medication = Medication(
        name: 'Doliprane',
        dosage: '500 mg',
        time: '08:00',
        scheduleTimes: const ['08:00', '14:00'],
        weekdaysMask: 21,
        startDate: DateTime(2026, 10, 8),
        endDate: DateTime(2026, 10, 15),
        reminderEnabled: true,
        activeIngredient: 'Paracétamol',
        commercialPresentation: '500 mg • Comprimé',
      );

      final id = await repository.create(medication);
      final created = await repository.getById(id);
      expect(created?.name, 'Doliprane');
      expect(created?.startDate, DateTime(2026, 10, 8));
      expect(created?.reminderEnabled, isTrue);
      expect(created?.activeIngredient, 'Paracétamol');
      expect(created?.commercialPresentation, '500 mg • Comprimé');
      expect(created?.scheduleTimes, ['08:00', '14:00']);
      expect(created?.weekdaysMask, 21);

      final updated = created!.copyWith(
        dosage: '1 comprimé',
        scheduleTimes: const ['09:00', '13:00'],
        weekdaysMask: 127,
        reminderEnabled: false,
      );
      expect(await repository.update(updated), 1);
      final reloaded = await repository.getById(id);
      expect(reloaded?.dosage, '1 comprimé');
      expect(reloaded?.reminderEnabled, isFalse);
      expect(reloaded?.activeIngredient, 'Paracétamol');
      expect(reloaded?.commercialPresentation, '500 mg • Comprimé');
      expect(reloaded?.scheduleTimes, ['09:00', '13:00']);
      expect(reloaded?.weekdaysMask, 127);
      expect((await repository.getAll()).single.id, id);

      expect(await repository.delete(id), 1);
      expect(await repository.getById(id), isNull);
      expect(await repository.getAll(), isEmpty);
    },
  );

  test('archiving removes future doses but retains recorded history', () async {
    final repository = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(repository.close);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final medicationId = await repository.create(
      Medication(
        name: 'Historique conservé',
        dosage: '1 comprimé',
        time: '08:00',
        startDate: yesterday,
        endDate: tomorrow,
        reminderEnabled: false,
      ),
    );
    await repository.ensureOccurrences(from: yesterday, through: tomorrow);
    var occurrences = await repository.getOccurrences(
      from: yesterday,
      through: tomorrow,
    );
    expect(occurrences, hasLength(3));

    await repository.markOccurrenceTaken(occurrences[0].id);
    await repository.ignoreOccurrence(occurrences[1].id);
    expect(await repository.delete(medicationId), 1);

    expect(await repository.getById(medicationId), isNull);
    expect(await repository.getAll(), isEmpty);
    expect(
      await repository.ensureOccurrences(from: tomorrow, through: tomorrow),
      0,
    );
    expect(
      await repository.getOccurrences(from: yesterday, through: tomorrow),
      hasLength(2),
    );
    expect(
      await repository.getOccurrencesForMedication(medicationId),
      hasLength(2),
    );
    expect(
      await repository.getOccurrences(from: tomorrow, through: tomorrow),
      isEmpty,
    );
  });

  test('migrates existing medication rows without losing their data', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sahacare_medications_migration_',
    );
    final databasePath = path.join(directory.path, 'medications.db');
    final legacyDatabase = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: sqflite.OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE medications (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              dosage TEXT NOT NULL,
              time TEXT NOT NULL,
              start_date TEXT NOT NULL,
              end_date TEXT NOT NULL,
              reminder_enabled INTEGER NOT NULL DEFAULT 1
            )
          ''');
          await database.insert('medications', {
            'name': 'Traitement existant',
            'dosage': '1 comprimé',
            'time': '08:00',
            'start_date': '2026-10-08',
            'end_date': '2026-10-15',
            'reminder_enabled': 1,
          });
        },
      ),
    );
    await legacyDatabase.close();

    final repository = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(() async {
      await repository.close();
      await File(databasePath).delete();
      await directory.delete();
    });

    final migrated = await repository.getById(1);
    expect(migrated?.name, 'Traitement existant');
    expect(migrated?.dosage, '1 comprimé');
    expect(migrated?.reminderEnabled, isTrue);
    expect(migrated?.activeIngredient, isNull);
    expect(migrated?.commercialPresentation, isNull);
    expect(migrated?.scheduleTimes, ['08:00']);
    expect(migrated?.weekdaysMask, 127);
  });

  test(
    'generates only selected days and prevents duplicate occurrences',
    () async {
      final repository = MedicationRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(repository.close);
      await repository.create(
        Medication(
          name: 'Calendrier test',
          dosage: 'selon ordonnance',
          time: '08:00',
          scheduleTimes: const ['08:00', '14:00'],
          weekdaysMask: 21,
          startDate: DateTime(2026, 10, 26),
          endDate: DateTime(2026, 10, 30),
          reminderEnabled: false,
        ),
      );

      final rangeStart = DateTime(2026, 10, 26);
      final rangeEnd = DateTime(2026, 11, 1);
      expect(
        await repository.ensureOccurrences(from: rangeStart, through: rangeEnd),
        6,
      );
      expect(
        await repository.ensureOccurrences(from: rangeStart, through: rangeEnd),
        0,
      );

      final occurrences = await repository.getOccurrences(
        from: rangeStart,
        through: rangeEnd,
      );
      expect(occurrences, hasLength(6));
      expect(
        occurrences
            .map((occurrence) => occurrence.scheduledDate.weekday)
            .toSet(),
        {DateTime.monday, DateTime.wednesday, DateTime.friday},
      );
      expect(
        occurrences.map((occurrence) => occurrence.scheduledTime).toSet(),
        {'08:00', '14:00'},
      );
      expect(
        occurrences.first.statusLabel(now: DateTime(2026, 10, 26, 7)),
        'À venir',
      );
      expect(
        occurrences.first.statusLabel(now: DateTime(2026, 10, 26, 9)),
        'En attente de confirmation',
      );

      await repository.markOccurrenceTaken(occurrences.first.id);
      final taken = await repository.getOccurrences(
        from: rangeStart,
        through: rangeEnd,
      );
      expect(
        taken
            .firstWhere((occurrence) => occurrence.id == occurrences.first.id)
            .status,
        MedicationOccurrenceStatus.taken,
      );
    },
  );

  test('records postponed dates and explicit confirmation', () async {
    final repository = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(repository.close);
    await repository.create(
      Medication(
        name: 'Report test',
        dosage: 'selon ordonnance',
        time: '08:00',
        startDate: DateTime(2026, 10, 26),
        endDate: DateTime(2026, 10, 30),
        reminderEnabled: false,
      ),
    );
    await repository.ensureOccurrences(
      from: DateTime(2026, 10, 26),
      through: DateTime(2026, 10, 30),
    );
    final occurrences = await repository.getOccurrences(
      from: DateTime(2026, 10, 26),
      through: DateTime(2026, 10, 30),
    );
    final occurrence = occurrences.first;

    await repository.postponeOccurrence(
      occurrenceId: occurrence.id,
      date: DateTime(2026, 10, 27),
      time: '09:30',
    );
    var postponed = await repository.getOccurrences(
      from: DateTime(2026, 10, 26),
      through: DateTime(2026, 10, 30),
    );
    var updated = postponed.firstWhere((item) => item.id == occurrence.id);
    expect(updated.status, MedicationOccurrenceStatus.postponed);
    expect(updated.effectiveDate, DateTime(2026, 10, 27));
    expect(updated.effectiveTime, '09:30');

    await repository.markOccurrenceTaken(occurrence.id);
    postponed = await repository.getOccurrences(
      from: DateTime(2026, 10, 26),
      through: DateTime(2026, 10, 30),
    );
    updated = postponed.firstWhere((item) => item.id == occurrence.id);
    expect(updated.status, MedicationOccurrenceStatus.taken);
    expect(updated.effectiveDate, DateTime(2026, 10, 27));
    expect(updated.effectiveTime, '09:30');
  });

  test('rejects duplicate times and empty weekday selections', () async {
    final repository = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(repository.close);
    final medication = Medication(
      name: 'Validation test',
      dosage: 'selon ordonnance',
      time: '08:00',
      scheduleTimes: const ['08:00', '08:00'],
      startDate: DateTime(2026, 10, 26),
      endDate: DateTime(2026, 10, 30),
      reminderEnabled: false,
    );
    await expectLater(
      repository.create(medication),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      repository.create(
        medication.copyWith(scheduleTimes: const ['08:00'], weekdaysMask: 0),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('supports continuous treatments without an end date', () async {
    final repository = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(repository.close);
    final id = await repository.create(
      Medication(
        name: 'Traitement continu',
        dosage: 'selon ordonnance',
        time: '08:00',
        startDate: DateTime(2026, 10, 26),
        reminderEnabled: false,
      ),
    );

    expect((await repository.getById(id))?.endDate, isNull);
    expect(
      await repository.ensureOccurrences(
        from: DateTime(2026, 10, 26),
        through: DateTime(2026, 10, 28),
      ),
      3,
    );
  });

  test(
    'keeps medication data when the database connection is reopened',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sahacare_medications_',
      );
      final databasePath = path.join(directory.path, 'medications.db');
      final firstRepository = MedicationRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      final id = await firstRepository.create(
        Medication(
          name: 'Traitement persistant',
          dosage: '10 mg',
          time: '09:30',
          startDate: DateTime(2026, 10, 22),
          endDate: DateTime(2026, 10, 29),
          reminderEnabled: false,
        ),
      );
      await firstRepository.close();

      final reopenedRepository = MedicationRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      addTearDown(() async {
        await reopenedRepository.close();
        await File(databasePath).delete();
        await directory.delete();
      });

      final medication = await reopenedRepository.getById(id);
      expect(medication?.name, 'Traitement persistant');
      expect(medication?.reminderEnabled, isFalse);
    },
  );

  test('surfaces SQLite schema errors to callers', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sahacare_medications_error_',
    );
    final databasePath = path.join(directory.path, 'medications.db');
    final malformedDatabase = await databaseFactoryFfi.openDatabase(
      databasePath,
    );
    await malformedDatabase.execute(
      'CREATE TABLE medications (id INTEGER PRIMARY KEY, value TEXT)',
    );
    await malformedDatabase.close();

    final repository = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(() async {
      await repository.close();
      await File(databasePath).delete();
      await directory.delete();
    });

    await expectLater(repository.getAll(), throwsA(isA<Exception>()));
  });
}
