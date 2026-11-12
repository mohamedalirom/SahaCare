import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/core/database/platform_db/db_init.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';

void main() {
  test('persists medication CRUD in browser-backed SQLite', () async {
    expect(kIsWeb, isTrue);
    initPlatformDatabase();
    const databasePath = 'medication_web_crud_test.db';
    final repository = MedicationRepository(databasePath: databasePath);
    addTearDown(repository.close);
    for (final oldMedication in await repository.getAll()) {
      final id = oldMedication.id;
      if (id != null) await repository.delete(id);
    }

    final id = await repository.create(
      Medication(
        name: 'Web CRUD',
        dosage: '250 mg',
        time: '08:15',
        startDate: DateTime(2026, 10, 22),
        endDate: DateTime(2026, 10, 30),
        reminderEnabled: true,
      ),
    );
    expect((await repository.getAll()).single.id, id);

    final updated = (await repository.getById(id))!
        .copyWith(dosage: '500 mg', reminderEnabled: false);
    expect(await repository.update(updated), 1);
    await repository.close();

    final reopenedRepository = MedicationRepository(databasePath: databasePath);
    addTearDown(reopenedRepository.close);
    final persisted = await reopenedRepository.getById(id);
    expect(persisted?.dosage, '500 mg');
    expect(persisted?.reminderEnabled, isFalse);

    expect(await reopenedRepository.delete(id), 1);
    expect(await reopenedRepository.getAll(), isEmpty);
  }, skip: !kIsWeb);
}
