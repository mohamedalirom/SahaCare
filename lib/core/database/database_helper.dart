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
      version: 5,
      onConfigure: _onConfigureDB,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: _onOpenDB,
    );
  }

  Future<void> _onConfigureDB(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
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

    // 5. Appointments & Doctors Tables
    await createAppointmentsTables(db);

    // 6. Specialties & Orientation History Tables
    await createOrientationTables(db);
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

  static Future<void> createAppointmentsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS doctors (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        specialty TEXT NOT NULL,
        hospital_or_clinic TEXT NOT NULL,
        address TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL,
        rating REAL NOT NULL DEFAULT 5.0,
        reviews_count INTEGER NOT NULL DEFAULT 0,
        consultation_fee REAL NOT NULL DEFAULT 60.0,
        bio TEXT NOT NULL DEFAULT '',
        available_days TEXT NOT NULL,
        available_slots TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointments (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        patient_id TEXT,
        doctor_name TEXT NOT NULL,
        doctor_specialty TEXT NOT NULL,
        doctor_address TEXT NOT NULL,
        doctor_phone TEXT NOT NULL,
        date_time TEXT NOT NULL,
        time_slot TEXT NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL,
        reminder TEXT NOT NULL,
        notification_enabled INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        fee REAL NOT NULL DEFAULT 60.0,
        FOREIGN KEY (doctor_id) REFERENCES doctors (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments (date_time ASC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_appointments_doctor ON appointments (doctor_id)');
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
    if (oldVersion < 4) {
      await createAppointmentsTables(db);
    }
    if (oldVersion < 5) {
      await createOrientationTables(db);
    }
  }

  static Future<void> createOrientationTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS specialties (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        icon_name TEXT NOT NULL,
        doctors_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS orientation_history (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        text TEXT NOT NULL,
        suggested_specialties TEXT NOT NULL,
        urgency TEXT NOT NULL,
        advice TEXT NOT NULL
      )
    ''');

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM specialties'),
    ) ?? 0;

    if (count == 0) {
      final batch = db.batch();
      final defaultSpecialties = [
        {'id': 'general', 'name': 'Médecine Générale', 'icon_name': 'medical_services'},
        {'id': 'cardio', 'name': 'Cardiologie', 'icon_name': 'favorite'},
        {'id': 'derma', 'name': 'Dermatologie', 'icon_name': 'clean_hands'},
        {'id': 'pediatry', 'name': 'Pédiatrie', 'icon_name': 'child_care'},
        {'id': 'ophtalmo', 'name': 'Ophtalmologie', 'icon_name': 'visibility'},
        {'id': 'dentist', 'name': 'Dentiste', 'icon_name': 'mood'},
        {'id': 'gyneco', 'name': 'Gynécologie', 'icon_name': 'pregnant_woman'},
        {'id': 'neuro', 'name': 'Neurologie', 'icon_name': 'psychology'},
        {'id': 'ortho', 'name': 'Orthopédie', 'icon_name': 'accessibility_new'},
        {'id': 'psychiatry', 'name': 'Psychiatrie', 'icon_name': 'self_improvement'},
        {'id': 'orl', 'name': 'ORL', 'icon_name': 'hearing'},
        {'id': 'pneumo', 'name': 'Pneumologie', 'icon_name': 'air'},
        {'id': 'gastro', 'name': 'Gastro-entérologie', 'icon_name': 'restaurant'},
        {'id': 'uro', 'name': 'Urologie', 'icon_name': 'water_drop'},
        {'id': 'endocrino', 'name': 'Endocrinologie', 'icon_name': 'medication'},
      ];

      for (final s in defaultSpecialties) {
        batch.insert('specialties', {
          'id': s['id']!,
          'name': s['name']!,
          'icon_name': s['icon_name']!,
          'doctors_count': 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> close() async {
    final db = _database;
    _database = null; // next `database` access reopens a fresh connection
    if (db != null && db.isOpen) await db.close();
  }
}
