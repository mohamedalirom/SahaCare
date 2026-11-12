import 'helpers/medication_test_access.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/core/config/supabase_config.dart';
import 'package:sahacare/features/auth/services/auth_service.dart';
import 'package:sahacare/features/medications/data/services/medication_access.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sahacare/core/database/platform_db/db_init.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/data/services/medication_ownership_schema.dart';

void main() {
  test('real local-demo authority can reopen an isolated Web database', () async {
    initPlatformDatabase();
    AuthService.instance.initAuthListener();
    await MedicationAccess.instance.refresh();
    expect(MedicationAccess.instance.ready, isTrue);
    expect(MedicationAccess.instance.capture().owner, 'demo:local');
    final path =
        'medication_demo_authority_${DateTime.now().microsecondsSinceEpoch}.db';
    final first = MedicationRepository(databasePath: path);
    final id = await first.create(
      Medication(
        name: 'Fictitious Web demo',
        dosage: 'Fictitious units',
        time: '08:00',
        startDate: DateTime(2030, 1, 7),
        reminderEnabled: false,
      ),
    );
    await first.close();
    final reopened = MedicationRepository(databasePath: path);
    addTearDown(reopened.close);
    await reopened.prepareStorage();
    expect((await reopened.getById(id))?.name, 'Fictitious Web demo');
  }, skip: !kIsWeb || !SupabaseConfig.isDemoMode);

  test('persists medication CRUD in browser-backed SQLite', () async {
    expect(kIsWeb, isTrue);
    initPlatformDatabase();
    final databasePath =
        'medication_web_crud_${DateTime.now().microsecondsSinceEpoch}.db';
    final repository = MedicationRepository(
      access: testMedicationAccess(),
      databasePath: databasePath,
    );
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

    final reopenedRepository = MedicationRepository(
      access: testMedicationAccess(),
      databasePath: databasePath,
    );
    addTearDown(reopenedRepository.close);
    final persisted = await reopenedRepository.getById(id);
    expect(persisted?.dosage, '500 mg');
    expect(persisted?.reminderEnabled, isFalse);

    expect(await reopenedRepository.delete(id), 1);
    expect(await reopenedRepository.getAll(), isEmpty);
  }, skip: !kIsWeb);

  test(
    'Web version probe refuses legacy v6 without migrating or assigning it',
    () async {
      initPlatformDatabase();
      final path =
          'medication_web_v6_${DateTime.now().microsecondsSinceEpoch}.db';
      final fixture = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE legacy_fixture (note TEXT)');
            await db.insert('legacy_fixture', {
              'note': 'fictitious unowned history',
            });
          },
        ),
      );
      await fixture.close();
      final access = testMedicationAccess();
      final repository = MedicationRepository(
        access: access,
        databasePath: path,
      );
      addTearDown(repository.close);
      addTearDown(access.dispose);
      await expectLater(
        repository.prepareStorage(),
        throwsA(isA<MedicationMigrationRequired>()),
      );
      final unchanged = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      expect(await unchanged.getVersion(), 6);
      expect(
        (await unchanged.query('legacy_fixture')).single['note'],
        'fictitious unowned history',
      );
      await unchanged.close();
    },
    skip: !kIsWeb,
  );
}
