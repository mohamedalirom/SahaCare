import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/entities/medication.dart';

class MedicationRepository {
  MedicationRepository({DatabaseFactory? databaseFactory, String? databasePath})
    : _databaseFactoryOverride = databaseFactory,
      _databasePathOverride = databasePath;

  static final MedicationRepository instance = MedicationRepository();

  final DatabaseFactory? _databaseFactoryOverride;
  final String? _databasePathOverride;
  Database? _database;

  Future<List<Medication>> getAll() async {
    final rows = await (await _getDatabase()).query(
      'medications',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Medication.fromMap).toList();
  }

  Future<Medication?> getById(int id) async {
    final rows = await (await _getDatabase()).query(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Medication.fromMap(rows.first);
  }

  Future<int> create(Medication medication) async {
    return (await _getDatabase()).insert(
      'medications',
      medication.toMap()..remove('id'),
    );
  }

  Future<int> update(Medication medication) async {
    final id = medication.id;
    if (id == null) {
      throw ArgumentError.value(id, 'medication.id', 'Must not be null');
    }
    return (await _getDatabase()).update(
      'medications',
      medication.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    return (await _getDatabase()).delete(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final factory = _databaseFactoryOverride ?? _platformDatabaseFactory();
    final databasePath = _databasePathOverride ?? await _getDatabasePath();
    _database = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
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
        },
      ),
    );
    return _database!;
  }

  DatabaseFactory _platformDatabaseFactory() {
    if (kIsWeb) {
      throw UnsupportedError(
        'Le stockage SQLite des médicaments n’est pas disponible sur le Web.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        sqfliteFfiInit();
        return databaseFactoryFfi;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return sqflite.databaseFactory;
    }
  }

  Future<String> _getDatabasePath() async {
    if (_databaseFactoryOverride != null) {
      throw StateError(
        'databasePath is required with a custom databaseFactory.',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final directory = await getApplicationDocumentsDirectory();
      return path.join(directory.path, 'sahacare_medications.db');
    }
    return path.join(
      await sqflite.getDatabasesPath(),
      'sahacare_medications.db',
    );
  }
}
