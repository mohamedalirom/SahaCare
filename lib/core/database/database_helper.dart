import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'platform_db/db_init.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sahacare_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    initPlatformDatabase();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: _onOpenDB,
    );
  }

  Future<void> _onOpenDB(Database db) async {
    // Defensive check: ensure is_visible_to_doctors exists regardless of past version quirks
    try {
      final info = await db.rawQuery("PRAGMA table_info(profiles)");
      final hasColumn = info.any((col) => col['name'] == 'is_visible_to_doctors');
      if (!hasColumn) {
        await db.execute('ALTER TABLE profiles ADD COLUMN is_visible_to_doctors INTEGER NOT NULL DEFAULT 1');
      }
    } catch (_) {}
  }

  Future _createDB(Database db, int version) async {
    // 1. Profiles Table
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        email TEXT,
        full_name TEXT,
        date_of_birth TEXT,
        biological_sex TEXT,
        blood_group TEXT,
        rhesus TEXT,
        height_cm REAL,
        weight_kg REAL,
        smoking_status TEXT,
        alcohol_consumption TEXT,
        physical_activity TEXT,
        is_visible_to_doctors INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER
      )
    ''');

    // 2. Allergies Table (full CRUD through the outbox)
    await db.execute('''
      CREATE TABLE allergies (
        id TEXT PRIMARY KEY,
        profile_id TEXT,
        name TEXT,
        severity TEXT,
        kind TEXT,
        updated_at INTEGER
      )
    ''');

    // 3. Diseases Table (full CRUD through the outbox)
    await db.execute('''
      CREATE TABLE diseases (
        id TEXT PRIMARY KEY,
        profile_id TEXT,
        name TEXT,
        diagnosed_at TEXT,
        is_chronic INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER
      )
    ''');

    // 3b. Medical history (antécédents)
    await _createMedicalHistoryTable(db);

    // 4. Sync Queue (Outbox Pattern)
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        operation TEXT NOT NULL,
        table_name TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createMedicalHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medical_history (
        id TEXT PRIMARY KEY,
        profile_id TEXT,
        title TEXT,
        description TEXT,
        event_date TEXT,
        updated_at INTEGER
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE allergies ADD COLUMN kind TEXT');
      await db.execute('ALTER TABLE diseases ADD COLUMN is_chronic INTEGER NOT NULL DEFAULT 0');
      await _createMedicalHistoryTable(db);
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE profiles ADD COLUMN is_visible_to_doctors INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
    }
  }

  Future<void> close() async {
    final db = _database;
    _database = null; // next `database` access reopens a fresh connection
    if (db != null && db.isOpen) await db.close();
  }
}
