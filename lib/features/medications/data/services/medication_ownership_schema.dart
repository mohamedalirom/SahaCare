import 'package:sqflite/sqflite.dart';

class MedicationMigrationRequired implements Exception {
  const MedicationMigrationRequired(this.version);
  final int version;
  @override
  String toString() =>
      'Base Médicaments version $version : migration vers 7 non autorisée. Les anciennes données sont conservées.';
}

/// Additive only. Existing rows remain owner NULL, never assigned on login.
/// Called only for a new empty database or an explicitly authorized isolated DB.
Future<void> addMedicationOwnershipSchema(DatabaseExecutor db) async {
  if (!(await db.rawQuery('PRAGMA table_info(medications)'))
      .any((r) => r['name'] == 'owner_id')) {
    await db.execute('ALTER TABLE medications ADD COLUMN owner_id TEXT');
  }
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_medications_owner ON medications(owner_id, deleted_at, id)',
  );
  if (!(await db.rawQuery(
    'PRAGMA table_info(medication_notification_registry)',
  )).any((r) => r['name'] == 'owner_id')) {
    await db.execute(
      'ALTER TABLE medication_notification_registry ADD COLUMN owner_id TEXT',
    );
  }
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_medication_notification_owner ON medication_notification_registry(owner_id, id)',
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS medication_ownership_audit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    medication_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE RESTRICT,
    owner_id TEXT NOT NULL,
    assigned_at TEXT NOT NULL,
    authorization_ref TEXT NOT NULL
  )''');
  // Defense against malformed cross-treatment schedule links. No historical
  // data is removed; an inconsistent graph aborts the whole migration.
  final inconsistent = await db.rawQuery(
    '''SELECT o.id FROM medication_occurrences o
    JOIN medication_schedules s ON s.id=o.schedule_id
    WHERE s.medication_id != o.medication_id LIMIT 1''',
  );
  if (inconsistent.isNotEmpty) {
    throw StateError('Liens historiques incohérents : migration annulée.');
  }
  final mixedMovements = await db.rawQuery(
    '''SELECT r.id FROM medication_stock_movements r
    JOIN medication_stock_movements a ON a.id=r.resolves_id
    WHERE r.medication_id!=a.medication_id LIMIT 1''',
  );
  if (mixedMovements.isNotEmpty) {
    throw StateError('Historique de stock incohérent : migration annulée.');
  }
  if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
    throw StateError('Intégrité référentielle invalide : migration annulée.');
  }
}
