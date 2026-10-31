import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/entities/medication_occurrence.dart';
import 'package:sahacare/features/medications/domain/entities/medication_stock.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late MedicationRepository repo;
  final day = DateTime(2030, 1, 7);
  StockQuantity q(String value) => StockQuantity.parse(value);
  MedicationStock stock({
    String initial = '10',
    String perDose = '1.5',
    StockUnit unit = StockUnit.tablet,
    bool enabled = true,
  }) => MedicationStock(
    enabled: enabled,
    unit: unit,
    initialQuantity: q(initial),
    remaining: q(initial),
    unitsPerDose: q(perDose),
    lowThreshold: q('2'),
    referenceQuantity: q(initial),
  );
  Medication medicine({MedicationStock? inventory}) => Medication(
    name: 'Stock test',
    dosage: '500 mg',
    time: '08:00',
    scheduleTimes: const ['08:00', '18:00'],
    startDate: day,
    endDate: day.add(const Duration(days: 3)),
    reminderEnabled: false,
    stock: inventory,
  );
  Future<List<MedicationOccurrence>> doses(int id) async {
    await repo.ensureOccurrences(from: day, through: day);
    return repo.getOccurrencesForMedication(id);
  }

  Future<MedicationStock> current(int id) async =>
      (await repo.getById(id))!.stock!;
  setUp(() {
    repo = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });
  tearDown(() => repo.close());

  test(
    'initial quantity and threshold persist independently of text dosage',
    () async {
      final id = await repo.create(medicine(inventory: stock()));
      final stored = await current(id);
      expect(stored.remaining, q('10'));
      expect(stored.unitsPerDose, q('1.5'));
      expect(stored.unit, StockUnit.tablet);
      expect((await repo.getById(id))!.dosage, '500 mg');
      final moves = await repo.stockMovements(id);
      expect(moves.single.kind, 'initial');
      expect(moves.single.delta, q('10'));
    },
  );
  test(
    'only confirmation debits; ignored and postponed doses do not',
    () async {
      final id = await repo.create(medicine(inventory: stock()));
      final occurrences = await doses(id);
      await repo.postponeOccurrence(
        occurrenceId: occurrences.first.id,
        date: day,
        time: '20:00',
      );
      await repo.ignoreOccurrence(occurrences.last.id);
      expect((await current(id)).remaining, q('10'));
      await repo.markOccurrenceTaken(occurrences.first.id);
      expect((await current(id)).remaining, q('8.5'));
      expect(
        (await repo.stockMovements(id))
            .where((m) => m.kind == 'consumption')
            .length,
        1,
      );
    },
  );
  test(
    'concurrent and repeated confirmations debit once, including status cycles',
    () async {
      final id = await repo.create(medicine(inventory: stock()));
      final occurrence = (await doses(id)).first;
      await Future.wait([
        repo.markOccurrenceTaken(occurrence.id),
        repo.markOccurrenceTaken(occurrence.id),
      ]);
      await repo.ignoreOccurrence(occurrence.id);
      await repo.postponeOccurrence(
        occurrenceId: occurrence.id,
        date: day,
        time: '20:00',
      );
      await repo.markOccurrenceTaken(occurrence.id);
      expect((await current(id)).remaining, q('8.5'));
      expect(
        (await repo.stockMovements(id))
            .where((m) => m.kind == 'consumption')
            .length,
        1,
      );
    },
  );
  test('insufficient stock confirms with zero debit and a single unresolved anomaly', () async {
    final id = await repo.create(
      medicine(
        inventory: stock(initial: '1', perDose: '2'),
      ),
    );
    final occurrence = (await doses(id)).first;
    await repo.markOccurrenceTaken(occurrence.id);
    await repo.markOccurrenceTaken(occurrence.id);
    expect(
      (await repo.getOccurrencesForMedication(id)).first.status,
      MedicationOccurrenceStatus.taken,
    );
    expect((await current(id)).remaining, q('1'));
    expect((await current(id)).pendingAnomalies, 1);
    final anomaly = (await repo.stockMovements(id))
        .singleWhere((m) => m.kind == 'anomaly');
    expect(anomaly.delta.milliUnits, 0);
    expect(anomaly.requiredQuantity, q('2'));
    expect(anomaly.quantityAfter, q('1'));
    expect(anomaly.unresolved, isTrue);
    await expectLater(
      repo.resolveStockAnomaly(id, anomaly.id),
      throwsStateError,
    );
    expect((await current(id)).remaining, q('1'));
  });
  test('restocking never retries an anomalous debit; explicit resolution is idempotent', () async {
    final id = await repo.create(
      medicine(
        inventory: stock(initial: '1', perDose: '2'),
      ),
    );
    final occurrence = (await doses(id)).first;
    await repo.markOccurrenceTaken(occurrence.id);
    final anomaly = (await repo.stockMovements(id)).first;
    await repo.replenishStock(id, q('5'));
    await repo.markOccurrenceTaken(occurrence.id);
    expect((await current(id)).remaining, q('6'));
    expect((await current(id)).pendingAnomalies, 1);
    await Future.wait([
      repo.resolveStockAnomaly(id, anomaly.id),
      repo.resolveStockAnomaly(id, anomaly.id),
    ]);
    expect((await current(id)).remaining, q('4'));
    expect((await current(id)).pendingAnomalies, 0);
    expect(
      (await repo.stockMovements(id))
          .where((m) => m.kind == 'resolution')
          .length,
      1,
    );
  });
  test('physical correction reconciles only explicitly selected anomalies, without another debit', () async {
    final id = await repo.create(
      medicine(
        inventory: stock(initial: '0', perDose: '2'),
      ),
    );
    for (final occurrence in await doses(id)) {
      await repo.markOccurrenceTaken(occurrence.id);
    }
    final anomalies = (await repo.stockMovements(id))
        .where((m) => m.unresolved)
        .toList();
    await repo.correctStockQuantity(id, q('0'), reason: 'Comptage initial');
    expect((await current(id)).pendingAnomalies, 2);
    await repo.correctStockQuantity(
      id,
      q('3'),
      reason: 'Comptage tenant compte d’une prise',
      reconciledAnomalyIds: [anomalies.first.id],
    );
    expect((await current(id)).remaining, q('3'));
    expect((await current(id)).pendingAnomalies, 1);
    expect(
      (await repo.stockMovements(id))
          .singleWhere((m) => m.kind == 'inventory_reconciliation')
          .delta
          .milliUnits,
      0,
    );
  });
  test('enabling tracking does not debit earlier confirmations, even after status changes', () async {
    final id = await repo.create(medicine());
    final occurrence = (await doses(id)).first;
    await repo.markOccurrenceTaken(occurrence.id);
    await repo.update((await repo.getById(id))!.copyWith(stock: stock()));
    await repo.ignoreOccurrence(occurrence.id);
    await repo.markOccurrenceTaken(occurrence.id);
    expect((await current(id)).remaining, q('10'));
    expect(
      (await repo.stockMovements(id)).where((m) => m.kind == 'consumption'),
      isEmpty,
    );
  });
  test('disabled tracking preserves quantities and receipts, without catch-up on reactivation', () async {
    final id = await repo.create(medicine(inventory: stock(enabled: false)));
    final occurrence = (await doses(id)).first;
    await repo.markOccurrenceTaken(occurrence.id);
    expect((await current(id)).remaining, q('10'));
    await repo.update((await repo.getById(id))!.copyWith(stock: stock()));
    await repo.markOccurrenceTaken(occurrence.id);
    expect((await current(id)).remaining, q('10'));
  });
  test('stale forms never reset stock and new per-dose quantities affect only future confirmations', () async {
    final id = await repo.create(medicine(inventory: stock()));
    final stale = (await repo.getById(id))!;
    final occurrences = await doses(id);
    await repo.markOccurrenceTaken(occurrences.first.id);
    await repo.update(
      stale.copyWith(stock: stale.stock!.copyWith(unitsPerDose: q('2.5'))),
    );
    expect((await current(id)).remaining, q('8.5'));
    final refreshed = await doses(id);
    await repo.markOccurrenceTaken(refreshed.last.id);
    expect((await current(id)).remaining, q('6'));
    expect(
      (await repo.stockMovements(id))
          .where((m) => m.kind == 'consumption')
          .map((m) => m.requiredQuantity.milliUnits)
          .toSet(),
      {1500, 2500},
    );
  });
  test('liquids keep fractional units, replenish exactly and maintain gauge reference', () async {
    final id = await repo.create(
      medicine(
        inventory: stock(unit: StockUnit.milliliter, perDose: '2.5'),
      ),
    );
    await repo.markOccurrenceTaken((await doses(id)).first.id);
    await repo.replenishStock(id, q('1.25'));
    expect((await current(id)).remaining, q('8.75'));
    await repo.correctStockQuantity(
      id,
      q('12.125'),
      reason: 'Mesure du volume',
    );
    expect((await current(id)).fraction, 1);
    final movementTotal = (await repo.stockMovements(id))
        .fold<int>(0, (sum, m) => sum + m.delta.milliUnits);
    expect(movementTotal, 12125);
  });
  test('unit changes, fractional discrete units and invalid correction roll back safely', () async {
    final id = await repo.create(
      medicine(
        inventory: stock(unit: StockUnit.capsule, perDose: '1'),
      ),
    );
    final med = (await repo.getById(id))!;
    await expectLater(
      repo.update(
        med.copyWith(
          name: 'Must roll back',
          stock: stock(unit: StockUnit.milliliter),
        ),
      ),
      throwsStateError,
    );
    expect((await repo.getById(id))!.name, 'Stock test');
    await expectLater(repo.replenishStock(id, q('0.5')), throwsArgumentError);
    await expectLater(
      repo.correctStockQuantity(id, StockQuantity(-1), reason: 'Incorrect'),
      throwsArgumentError,
    );
    expect((await current(id)).remaining, q('10'));
    expect((await repo.stockMovements(id)).length, 1);
  });
  test(
    'archiving preserves stock and its immutable movement history',
    () async {
      final id = await repo.create(medicine(inventory: stock()));
      await repo.markOccurrenceTaken((await doses(id)).first.id);
      await repo.delete(id);
      expect(await repo.getById(id), isNull);
      expect((await repo.stockMovements(id)).length, 2);
    },
  );
  test(
    'a journal write failure rolls back both debit and intake confirmation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sahacare_stock_atomic_',
      );
      final file = '${directory.path}/stock.db';
      await repo.close();
      repo = MedicationRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: file,
      );
      final id = await repo.create(medicine(inventory: stock()));
      final occurrence = (await doses(id)).first;
      final db = await databaseFactoryFfi.openDatabase(file);
      await db.execute(
        "CREATE TRIGGER fail_stock_insert BEFORE INSERT ON medication_stock_movements WHEN NEW.kind = 'consumption' BEGIN SELECT RAISE(ABORT, 'injected stock failure'); END",
      );
      await expectLater(
        repo.markOccurrenceTaken(occurrence.id),
        throwsA(isA<DatabaseException>()),
      );
      expect((await current(id)).remaining, q('10'));
      expect(
        (await repo.getOccurrencesForMedication(id)).first.status,
        MedicationOccurrenceStatus.scheduled,
      );
      expect((await repo.stockMovements(id)).length, 1);
    },
  );
  test('migration 5 to 6 preserves all medical and notification rows with no retroactive debit', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sahacare_stock_migration_',
    );
    final file = '${directory.path}/stock.db';
    await repo.close();
    repo = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: file,
    );
    final id = await repo.create(medicine());
    final occurrence = (await doses(id)).first;
    await repo.markOccurrenceTaken(occurrence.id);
    await repo.notificationId('preserved-notification');
    await repo.close();
    final db = await databaseFactoryFfi.openDatabase(file);
    // Disposable fixture only. Reconstruct exactly the old v5 schema.
    await db.execute('DROP TABLE medication_stock_movements');
    await db.execute('DROP TABLE medication_stock');
    await db.setVersion(5);
    final tables = [
      'medications',
      'medication_schedules',
      'medication_schedule_times',
      'medication_occurrences',
      'medication_notification_registry',
    ];
    final before = {for (final table in tables) table: await db.query(table)};
    await db.close();
    repo = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: file,
    );
    expect((await repo.getById(id))!.stock, isNull);
    final afterDb = await databaseFactoryFfi.openDatabase(file);
    expect(await afterDb.getVersion(), 6);
    for (final table in tables) {
      expect(await afterDb.query(table), before[table], reason: table);
    }
    expect((await repo.stockMovements(id)).single.kind, 'legacy_confirmation');
    await repo.update((await repo.getById(id))!.copyWith(stock: stock()));
    await repo.ignoreOccurrence(occurrence.id);
    await repo.markOccurrenceTaken(occurrence.id);
    expect((await current(id)).remaining, q('10'));
    await repo.close();
    repo = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: file,
    );
    expect((await current(id)).remaining, q('10'));
    expect((await repo.stockMovements(id)).length, 2);
  });
}
