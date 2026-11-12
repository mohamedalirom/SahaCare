import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/data/services/medication_access.dart';
import 'package:sahacare/features/medications/data/services/medication_ownership_schema.dart';
import 'package:sahacare/features/medications/data/services/medication_report_service.dart';
import 'package:sahacare/features/medications/data/services/medication_report_pdf.dart';
import 'package:sahacare/features/medications/data/services/medication_report_actions.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/entities/medication_stock.dart';
import 'package:sahacare/features/medications/domain/entities/medication_report.dart';

import 'helpers/medication_test_access.dart';

class _ChangingPdf extends MedicationReportPdf {
  _ChangingPdf(this.change);
  final Future<void> Function() change;
  @override
  Future<Uint8List> build(MedicationReportData data) async {
    await change();
    return Uint8List.fromList([37, 80, 68, 70]);
  }
}

class _UnverifiedAuthority implements MedicationSessionAuthority {
  @override
  String? get stamp => 'unverified UI identifier';
  @override
  MedicationIdentity? get initialVerifiedIdentity => null;
  @override
  Future<MedicationIdentity?> verify() async => null;
}

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory directory;
  late String file;
  late TestMedicationAuthority authority;
  late MedicationAccess access;
  late MedicationRepository repo;
  final day = DateTime(2030, 1, 7);
  Medication medicine(String name, {bool stock = true}) => Medication(
    name: name,
    dosage: 'dose fictive',
    time: '08:00',
    scheduleTimes: const ['08:00', '20:00'],
    startDate: day,
    endDate: day.add(const Duration(days: 3)),
    reminderEnabled: true,
    stock: stock
        ? MedicationStock(
            enabled: true,
            unit: StockUnit.tablet,
            initialQuantity: StockQuantity(10000),
            remaining: StockQuantity(10000),
            unitsPerDose: StockQuantity(1000),
            lowThreshold: StockQuantity(2000),
            referenceQuantity: StockQuantity(10000),
          )
        : null,
  );
  Future<void> user(String? owner) async {
    authority.owner = owner;
    authority.revision++;
    await access.refresh();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sahacare_owner_test_');
    file = '${directory.path}/isolated.db';
    authority = TestMedicationAuthority(
      owner: 'supabase:fixture:A',
      demo: false,
    );
    access = MedicationAccess(authority: authority);
    repo = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: file,
      access: access,
    );
  });
  tearDown(() async {
    await repo.close();
    access.dispose();
  });
  test('A/B all reads, direct IDs, writes, archive, stocks and occurrences are isolated', () async {
    final a = await repo.create(medicine('Fictif A'));
    await repo.ensureOccurrences(from: day, through: day);
    final aDose = (await repo.getOccurrencesForMedication(a)).first.id;
    await user('supabase:fixture:B');
    final b = await repo.create(medicine('Fictif B'));
    await repo.ensureOccurrences(from: day, through: day);
    final bDose = (await repo.getOccurrencesForMedication(b)).first.id;
    expect((await repo.getAll()).map((m) => m.id), [b]);
    expect(await repo.getById(a), isNull);
    expect(await repo.getOccurrencesForMedication(a), isEmpty);
    expect(await repo.update(medicine('Intrusion').copyWith(id: a)), 0);
    expect(await repo.delete(a), 0);
    await expectLater(repo.markOccurrenceTaken(aDose), throwsStateError);
    await expectLater(repo.ignoreOccurrence(aDose), throwsStateError);
    await expectLater(
      repo.postponeOccurrence(occurrenceId: aDose, date: day, time: '10:00'),
      throwsStateError,
    );
    await expectLater(
      repo.replenishStock(a, StockQuantity(1000)),
      throwsStateError,
    );
    await expectLater(
      repo.correctStockQuantity(a, StockQuantity(1000), reason: 'intrusion'),
      throwsStateError,
    );
    await expectLater(repo.stockMovements(a), throwsStateError);
    await expectLater(repo.resolveStockAnomaly(a, 1), throwsStateError);
    expect(
      (await repo.getOccurrences(
        from: day,
        through: day,
      )).every((o) => o.medicationId == b),
      isTrue,
    );
    expect(
      (await repo.getAdherenceRecords(
        from: day,
        through: day,
      )).every((r) => r.occurrence.medicationId == b),
      isTrue,
    );
    await repo.markOccurrenceTaken(bDose);
    expect((await repo.getById(b))!.stock!.remaining.milliUnits, 9000);
    await repo.correctStockQuantity(
      b,
      StockQuantity(0),
      reason: 'fictitious shortage',
    );
    final otherBDose = (await repo.getOccurrencesForMedication(b))
        .firstWhere((o) => o.id != bDose)
        .id;
    await repo.markOccurrenceTaken(otherBDose);
    final bAnomaly = (await repo.stockMovements(b)).first.id;
    await user('supabase:fixture:A');
    await expectLater(
      repo.correctStockQuantity(
        a,
        StockQuantity(20000),
        reason: 'forged reconciliation',
        reconciledAnomalyIds: [bAnomaly],
      ),
      throwsStateError,
    );
    await expectLater(repo.resolveStockAnomaly(a, bAnomaly), throwsStateError);
    await repo.ensureOccurrences(
      from: day.add(const Duration(days: 1)),
      through: day.add(const Duration(days: 1)),
    );
    await user('supabase:fixture:B');
    expect((await repo.getOccurrencesForMedication(b)).length, 2);
    await user('supabase:fixture:A');
    expect((await repo.getAll()).single.id, a);
    expect(await repo.getById(b), isNull);
    await expectLater(repo.markOccurrenceTaken(bDose), throwsStateError);
    expect((await repo.getById(a))!.stock!.remaining.milliUnits, 10000);
    await repo.markOccurrenceTaken(aDose);
    await repo.markOccurrenceTaken(aDose);
    expect((await repo.getById(a))!.stock!.remaining.milliUnits, 9000);
    await repo.delete(a);
    expect(
      (await repo.getReportSnapshot(
        from: day,
        through: day,
      )).treatments.single.medication.id,
      a,
    );
    expect((await repo.stockMovements(a)).length, 2);
  });
  test('no session or expired authority cannot even create/open a medical database', () async {
    await user(null);
    await expectLater(repo.getAll(), throwsA(isA<MedicationAccessDenied>()));
    await expectLater(
      repo.create(medicine('interdit')),
      throwsA(isA<MedicationAccessDenied>()),
    );
    expect(await databaseFactoryFfi.databaseExists(file), isFalse);
    authority.owner = 'supabase:fixture:A';
    authority.expiresAt = DateTime.utc(2000);
    await access.refresh();
    await expectLater(repo.getAll(), throwsA(isA<MedicationAccessDenied>()));
    expect(await databaseFactoryFfi.databaseExists(file), isFalse);
  });
  test('stale errors cannot expose the old account details', () async {
    repo.onChanged = () async {
      await user('supabase:fixture:B');
      throw StateError('private details from A');
    };
    await expectLater(
      repo.create(medicine('A')),
      throwsA(isA<MedicationAccessDenied>()),
    );
    repo.onChanged = null;
    expect(await repo.getAll(), isEmpty);
  });
  test('registry keys and signatures never cross accounts', () async {
    final a = await repo.notificationId('same logical key');
    await repo.recordNotification(a, 'A');
    await user('supabase:fixture:B');
    expect(await repo.notificationRegistry(), isEmpty);
    final b = await repo.notificationId('same logical key');
    expect(a, isNot(b));
    await expectLater(repo.recordNotification(a, 'forged'), throwsStateError);
    await repo.recordNotification(b, 'B');
    await user('supabase:fixture:A');
    expect((await repo.notificationRegistry()).single['signature'], 'A');
  });
  test('an unverified UID is not session authorization', () async {
    final unverified = MedicationAccess(authority: _UnverifiedAuthority());
    final denied = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${directory.path}/never-opened.db',
      access: unverified,
    );
    await expectLater(
      denied.create(medicine('interdit')),
      throwsA(isA<MedicationAccessDenied>()),
    );
    expect(
      await databaseFactoryFfi.databaseExists(
        '${directory.path}/never-opened.db',
      ),
      isFalse,
    );
    await denied.close();
    unverified.dispose();
  });
  test(
    'an unauthenticated write is never adopted by a subsequent login',
    () async {
      await user(null);
      final refused = expectLater(
        repo.create(medicine('stale input A')),
        throwsA(isA<MedicationAccessDenied>()),
      );
      await user('supabase:fixture:B');
      await refused;
      expect(await repo.getAll(), isEmpty);
    },
  );
  test(
    'test migration permission cannot target a default production repository',
    () {
      expect(
        () =>
            MedicationRepository(access: access, allowIsolatedMigration: true),
        throwsArgumentError,
      );
    },
  );
  test(
    'an inconsistent historical graph rolls back the entire additive migration',
    () async {
      final a = await repo.create(medicine('A')),
          b = await repo.create(medicine('B'));
      await repo.ensureOccurrences(from: day, through: day);
      await repo.close();
      final legacy = await databaseFactoryFfi.openDatabase(file);
      final schedule = (await legacy.query(
        'medication_schedules',
        where: 'medication_id=?',
        whereArgs: [b],
      )).single['id'];
      final corruptId = (await legacy.query(
        'medication_occurrences',
        where: 'medication_id=?',
        whereArgs: [a],
        limit: 1,
      )).single['id'];
      await legacy.update(
        'medication_occurrences',
        {'schedule_id': schedule, 'scheduled_time': '11:11'},
        where: 'id=?',
        whereArgs: [corruptId],
      );
      await legacy.execute('DROP INDEX idx_medications_owner');
      await legacy.execute('ALTER TABLE medications DROP COLUMN owner_id');
      await legacy.execute('DROP INDEX idx_medication_notification_owner');
      await legacy.execute(
        'ALTER TABLE medication_notification_registry DROP COLUMN owner_id',
      );
      await legacy.execute('DROP TABLE medication_ownership_audit');
      await legacy.setVersion(6);
      final before = await legacy.query('medications', orderBy: 'id');
      await legacy.close();
      repo = MedicationRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: file,
        access: access,
        allowIsolatedMigration: true,
      );
      await expectLater(repo.prepareStorage(), throwsStateError);
      final check = await databaseFactoryFfi.openDatabase(file);
      expect(await check.getVersion(), 6);
      expect(await check.query('medications', orderBy: 'id'), before);
      expect(
        (await check.rawQuery('PRAGMA table_info(medications)'))
            .any((r) => r['name'] == 'owner_id'),
        isFalse,
      );
      expect(
        await check.rawQuery(
          "SELECT name FROM sqlite_master WHERE name='medication_ownership_audit'",
        ),
        isEmpty,
      );
      await check.close();
    },
  );
  test(
    'a result committed under A is never returned to B or attributed to B',
    () async {
      repo.onChanged = () => user('supabase:fixture:B');
      await expectLater(
        repo.create(medicine('Fictif A')),
        throwsA(isA<MedicationAccessDenied>()),
      );
      repo.onChanged = null;
      expect(await repo.getAll(), isEmpty);
      await user('supabase:fixture:A');
      expect((await repo.getAll()).single.name, 'Fictif A');
    },
  );
  test('PDF snapshots contain only current owner, old artifacts/leases expire on A→B→A', () async {
    final a = await repo.create(medicine('Fictif A'));
    final lease = access.capture();
    await user('supabase:fixture:B');
    final b = await repo.create(medicine('Fictif B'));
    final service = MedicationReportService(
      repository: repo,
      clock: () => day.add(const Duration(hours: 12)),
    );
    final data = await service.collect(
      MedicationReportOptions(from: day, through: day),
      acknowledgeAnonymous: true,
    );
    expect(data.treatments.single.medication.id, b);
    await user('supabase:fixture:A');
    expect((await repo.getAll()).single.id, a);
    expect(lease.check, throwsA(isA<MedicationAccessDenied>()));
    final newLease = access.capture();
    await user(null);
    expect(newLease.check, throwsA(isA<MedicationAccessDenied>()));
    await expectLater(
      service.choices(),
      throwsA(isA<MedicationAccessDenied>()),
    );
  });
  test('demo namespace remains distinct from both real accounts', () async {
    await repo.create(medicine('A'));
    authority.demo = true;
    await user('demo:local');
    expect(await repo.getAll(), isEmpty);
    await repo.create(medicine('Démo fictive'));
    authority.demo = false;
    await user('supabase:fixture:B');
    expect(await repo.getAll(), isEmpty);
    await user('supabase:fixture:A');
    expect((await repo.getAll()).single.name, 'A');
  });
  test('account switch while rendering PDF prevents an artifact or external delivery', () async {
    await repo.create(medicine('A'));
    final service = MedicationReportService(
      repository: repo,
      clock: () => day,
      pdf: _ChangingPdf(() => user('supabase:fixture:B')),
    );
    await expectLater(
      service.generate(
        MedicationReportOptions(from: day, through: day),
        acknowledgeAnonymous: true,
      ),
      throwsA(isA<MedicationAccessDenied>()),
    );
    await user('supabase:fixture:A');
    final lease = access.capture();
    final data =
        await MedicationReportService(
          repository: repo,
          clock: () => day,
        ).collect(
          MedicationReportOptions(from: day, through: day),
          acknowledgeAnonymous: true,
        );
    final artifact = MedicationReportArtifact(
      bytes: Uint8List.fromList([37, 80, 68, 70]),
      filename: 'fictitious-test.pdf',
      sessionKey: 'not an authorization proof',
      data: data,
      verifyAccess: lease.check,
    );
    await user('supabase:fixture:B');
    expect(
      () => MedicationReportActions().save(artifact),
      throwsA(isA<MedicationAccessDenied>()),
    );
  });
  test('6→7 is additive, unowned data invisible, production opening requires separate consent', () async {
    final id = await repo.create(medicine('Historique fictif'));
    await repo.ensureOccurrences(from: day, through: day);
    await repo.markOccurrenceTaken(
      (await repo.getOccurrencesForMedication(id)).first.id,
    );
    await repo.notificationId('historical');
    await repo.close();
    final db = await databaseFactoryFfi.openDatabase(file);
    // Disposable fixture only: reconstruct exact v6 columns without owners.
    await db.execute('DROP INDEX idx_medications_owner');
    await db.execute('ALTER TABLE medications DROP COLUMN owner_id');
    await db.execute('DROP INDEX idx_medication_notification_owner');
    await db.execute(
      'ALTER TABLE medication_notification_registry DROP COLUMN owner_id',
    );
    await db.execute('DROP TABLE medication_ownership_audit');
    await db.setVersion(6);
    final tables = [
      'medications',
      'medication_schedules',
      'medication_schedule_times',
      'medication_occurrences',
      'medication_stock',
      'medication_stock_movements',
      'medication_notification_registry',
    ];
    final before = {
      for (final table in tables)
        table: await db.query(
          table,
          orderBy: table == 'medication_stock' ? 'medication_id' : 'id',
        ),
    };
    await db.close();
    await expectLater(
      repo.getAll(),
      throwsA(isA<MedicationMigrationRequired>()),
    );
    final unchanged = await databaseFactoryFfi.openDatabase(file);
    expect(await unchanged.getVersion(), 6);
    await unchanged.close();
    repo = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: file,
      access: access,
      allowIsolatedMigration: true,
    );
    expect(await repo.getAll(), isEmpty);
    expect(await repo.getById(id), isNull);
    await expectLater(repo.markOccurrenceTaken(1), throwsStateError);
    expect(await repo.delete(id), 0);
    expect(await repo.notificationRegistry(), isEmpty);
    final migrated = await databaseFactoryFfi.openDatabase(file);
    expect(await migrated.getVersion(), 7);
    for (final table in tables) {
      final after = await migrated.query(
        table,
        orderBy: table == 'medication_stock' ? 'medication_id' : 'id',
      );
      expect(
        after.map((r) => Map.of(r)..remove('owner_id')).toList(),
        before[table],
      );
      if (table == 'medications' ||
          table == 'medication_notification_registry') {
        expect(after.every((r) => r['owner_id'] == null), isTrue);
      }
    }
    expect(await migrated.query('medication_ownership_audit'), isEmpty);
    expect(await migrated.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    // No ordinary repository operation claims or changes anonymous history.
    await user('supabase:fixture:B');
    expect(await repo.getAll(), isEmpty);
  });
}
