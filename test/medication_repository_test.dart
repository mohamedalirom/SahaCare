import 'package:flutter_test/flutter_test.dart';
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
}
