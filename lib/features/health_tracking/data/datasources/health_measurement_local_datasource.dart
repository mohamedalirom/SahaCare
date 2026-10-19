import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/platform_db/db_init.dart';
import '../../domain/entities/health_measurement.dart';
import '../models/health_measurement_model.dart';

abstract class HealthMeasurementLocalDataSource {
  Future<List<HealthMeasurementModel>> getMeasurements(String userId);
  Future<void> insertMeasurement(String userId, HealthMeasurementModel measurement);
  Future<void> updateMeasurement(String userId, HealthMeasurementModel measurement);
  Future<void> deleteMeasurement(String userId, String id);
}

/// Stockage SQLite des mesures de santé.
/// Base dédiée au module (sahacare_health.db) pour ne pas toucher au schéma
/// partagé de DatabaseHelper. Chaque ligne est rattachée à l'utilisateur connecté.
class HealthMeasurementLocalDataSourceImpl implements HealthMeasurementLocalDataSource {
  static const String _dbName = 'sahacare_health.db';
  static const String _table = 'health_measurements';
  static const String _seedTable = 'health_demo_seeded';

  /// Fabrique et chemin de base alternatifs (base en mémoire dans les tests)
  final DatabaseFactory? factoryOverride;
  final String? pathOverride;
  final _uuid = const Uuid();
  Database? _db;

  HealthMeasurementLocalDataSourceImpl({this.factoryOverride, this.pathOverride});

  Future<Database> get _database async {
    if (_db != null && _db!.isOpen) return _db!;
    initPlatformDatabase();
    final factory = factoryOverride ?? databaseFactory;
    final path = pathOverride ?? join(await factory.getDatabasesPath(), _dbName);
    _db = await factory.openDatabase(path, options: OpenDatabaseOptions(version: 1, onCreate: _createDB));
    return _db!;
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        id TEXT PRIMARY KEY,
        profile_id TEXT NOT NULL,
        type TEXT NOT NULL,
        value REAL NOT NULL,
        secondary_value REAL,
        glycemia_context TEXT,
        measured_at INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_health_profile_date ON $_table (profile_id, measured_at DESC)');
    // Mémorise les utilisateurs ayant déjà reçu les données de démonstration,
    // pour ne pas les réinsérer s'ils suppriment toutes leurs mesures.
    await db.execute('CREATE TABLE $_seedTable (profile_id TEXT PRIMARY KEY)');
  }

  /// Insère l'historique de démonstration une seule fois par utilisateur
  Future<void> _seedIfFirstLaunch(Database db, String userId) async {
    final seeded = await db.query(_seedTable, where: 'profile_id = ?', whereArgs: [userId]);
    if (seeded.isNotEmpty) return;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final m in HealthMeasurement.demoData(_uuid.v4)) {
        batch.insert(_table, HealthMeasurementModel.fromEntity(m).toMap(userId));
      }
      batch.insert(_seedTable, {'profile_id': userId});
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<HealthMeasurementModel>> getMeasurements(String userId) async {
    final db = await _database;
    await _seedIfFirstLaunch(db, userId);
    final rows = await db.query(_table, where: 'profile_id = ?', whereArgs: [userId], orderBy: 'measured_at DESC');
    return rows.map(HealthMeasurementModel.fromMap).toList();
  }

  @override
  Future<void> insertMeasurement(String userId, HealthMeasurementModel measurement) async {
    final db = await _database;
    await db.insert(_table, measurement.toMap(userId), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  @override
  Future<void> updateMeasurement(String userId, HealthMeasurementModel measurement) async {
    final db = await _database;
    final count = await db.update(
      _table,
      measurement.toMap(userId),
      where: 'id = ? AND profile_id = ?',
      whereArgs: [measurement.id, userId],
    );
    if (count == 0) throw StateError('Mesure introuvable');
  }

  @override
  Future<void> deleteMeasurement(String userId, String id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ? AND profile_id = ?', whereArgs: [id, userId]);
  }

  /// Ferme la connexion (rouverte automatiquement au prochain accès)
  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) await db.close();
  }
}
