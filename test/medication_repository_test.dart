import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
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
        startDate: DateTime(2026, 10, 8),
        endDate: DateTime(2026, 10, 15),
        reminderEnabled: true,
      );

      final id = await repository.create(medication);
      final created = await repository.getById(id);
      expect(created?.name, 'Doliprane');
      expect(created?.startDate, DateTime(2026, 10, 8));
      expect(created?.reminderEnabled, isTrue);

      final updated = created!.copyWith(
        dosage: '1 comprimé',
        reminderEnabled: false,
      );
      expect(await repository.update(updated), 1);
      final reloaded = await repository.getById(id);
      expect(reloaded?.dosage, '1 comprimé');
      expect(reloaded?.reminderEnabled, isFalse);
      expect((await repository.getAll()).single.id, id);

      expect(await repository.delete(id), 1);
      expect(await repository.getById(id), isNull);
      expect(await repository.getAll(), isEmpty);
    },
  );

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
