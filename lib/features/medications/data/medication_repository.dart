import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../../core/database/platform_db/db_init.dart';
import '../../../core/config/supabase_config.dart';
import '../domain/entities/medication.dart';
import '../domain/entities/medication_occurrence.dart';

class MedicationRepository {
  MedicationRepository({
    sqflite.DatabaseFactory? databaseFactory,
    String? databasePath,
  }) : _databaseFactoryOverride = databaseFactory,
       _databasePathOverride = databasePath;

  static final MedicationRepository instance = MedicationRepository();

  final sqflite.DatabaseFactory? _databaseFactoryOverride;
  final String? _databasePathOverride;
  sqflite.Database? _database;

  Future<List<Medication>> getAll() async {
    final database = await _getDatabase();
    final rows = await database.query(
      'medications',
      where: 'deleted_at IS NULL',
      orderBy: 'name COLLATE NOCASE',
    );
    final medications = <Medication>[];
    for (final row in rows) {
      medications.add(await _loadMedication(database, row));
    }
    return medications;
  }

  Future<Medication?> getById(int id) async {
    final database = await _getDatabase();
    final rows = await database.query(
      'medications',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _loadMedication(database, rows.first);
  }

  Future<int> create(Medication medication) async {
    final times = _validatedTimes(medication);
    final database = await _getDatabase();
    return database.transaction((transaction) async {
      final id = await transaction.insert(
        'medications',
        _medicationValues(medication, times),
      );
      await _saveSchedule(transaction, id, medication.weekdaysMask, times);
      return id;
    });
  }

  Future<int> update(Medication medication) async {
    final id = medication.id;
    if (id == null) {
      throw ArgumentError.value(id, 'medication.id', 'Must not be null');
    }
    final times = _validatedTimes(medication);
    final database = await _getDatabase();
    return database.transaction((transaction) async {
      final changed = await transaction.update(
        'medications',
        _medicationValues(medication, times),
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      if (changed == 0) return 0;
      await _saveSchedule(transaction, id, medication.weekdaysMask, times);
      return changed;
    });
  }

  Future<int> delete(int id) async {
    final database = await _getDatabase();
    return database.transaction((transaction) async {
      final deleted = await transaction.update(
        'medications',
        {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      if (deleted == 0) return 0;
      await transaction.delete(
        'medication_occurrences',
        where: 'medication_id = ? AND status = ?',
        whereArgs: [id, MedicationOccurrenceStatus.scheduled.name],
      );
      return deleted;
    });
  }

  Future<int> ensureOccurrences({
    required DateTime from,
    required DateTime through,
  }) async {
    final firstDay = _dateOnly(from);
    final lastDay = _dateOnly(through);
    if (lastDay.isBefore(firstDay)) {
      throw ArgumentError.value(through, 'through', 'Must not precede from');
    }

    final database = await _getDatabase();
    return database.transaction((transaction) async {
      final schedules = await transaction.rawQuery(
        '''
        SELECT s.id AS schedule_id, s.medication_id, s.weekdays_mask,
          m.start_date, m.end_date
        FROM medication_schedules s
        JOIN medications m ON m.id = s.medication_id
        WHERE m.deleted_at IS NULL
          AND m.start_date <= ?
          AND (m.end_date IS NULL OR m.end_date >= ?)
      ''',
        [_dateToDatabase(lastDay), _dateToDatabase(firstDay)],
      );
      var inserted = 0;

      for (final schedule in schedules) {
        final scheduleId = schedule['schedule_id'] as int;
        final medicationId = schedule['medication_id'] as int;
        final weekdaysMask = schedule['weekdays_mask'] as int;
        final medicationStart = DateTime.parse(
          schedule['start_date'] as String,
        );
        final medicationEnd = schedule['end_date'] == null
            ? null
            : DateTime.parse(schedule['end_date'] as String);
        final start = medicationStart.isAfter(firstDay)
            ? _dateOnly(medicationStart)
            : firstDay;
        final end = medicationEnd != null && medicationEnd.isBefore(lastDay)
            ? _dateOnly(medicationEnd)
            : lastDay;
        final times = await transaction.query(
          'medication_schedule_times',
          columns: ['time'],
          where: 'schedule_id = ?',
          whereArgs: [scheduleId],
          orderBy: 'position, time',
        );

        for (
          var day = start;
          !day.isAfter(end);
          day = day.add(const Duration(days: 1))
        ) {
          final weekdayBit = 1 << (day.weekday - 1);
          if (weekdaysMask & weekdayBit == 0) continue;
          for (final timeRow in times) {
            final time = timeRow['time'] as String;
            if (_normalizeTime(time) == null) continue;
            final rowId = await transaction.insert('medication_occurrences', {
              'medication_id': medicationId,
              'schedule_id': scheduleId,
              'scheduled_date': _dateToDatabase(day),
              'scheduled_time': time,
              'status': 'scheduled',
            }, conflictAlgorithm: sqflite.ConflictAlgorithm.ignore);
            if (rowId > 0) inserted++;
          }
        }
      }
      return inserted;
    });
  }

  Future<List<MedicationOccurrence>> getOccurrences({
    required DateTime from,
    required DateTime through,
  }) async {
    final database = await _getDatabase();
    final rows = await database.rawQuery(
      '''
      SELECT o.*, m.name AS medication_name, m.dosage AS medication_dosage,
        m.start_date AS medication_start_date,
        m.end_date AS medication_end_date,
        m.active_ingredient AS medication_active_ingredient
      FROM medication_occurrences o
      JOIN medications m ON m.id = o.medication_id
      WHERE COALESCE(o.rescheduled_date, o.scheduled_date) BETWEEN ? AND ?
        AND (
          m.deleted_at IS NULL
          OR COALESCE(o.rescheduled_date, o.scheduled_date) <= ?
        )
      ORDER BY COALESCE(o.rescheduled_date, o.scheduled_date),
        COALESCE(o.rescheduled_time, o.scheduled_time), m.name COLLATE NOCASE
    ''',
      [
        _dateToDatabase(from),
        _dateToDatabase(through),
        _dateToDatabase(DateTime.now()),
      ],
    );
    return rows.map(MedicationOccurrence.fromMap).toList();
  }

  Future<List<MedicationOccurrence>> getOccurrencesForMedication(
    int medicationId,
  ) async {
    final database = await _getDatabase();
    final rows = await database.rawQuery(
      '''
      SELECT o.*, m.name AS medication_name, m.dosage AS medication_dosage,
        m.start_date AS medication_start_date,
        m.end_date AS medication_end_date,
        m.active_ingredient AS medication_active_ingredient
      FROM medication_occurrences o
      JOIN medications m ON m.id = o.medication_id
      WHERE o.medication_id = ?
      ORDER BY COALESCE(o.rescheduled_date, o.scheduled_date) DESC,
        COALESCE(o.rescheduled_time, o.scheduled_time) DESC
      ''',
      [medicationId],
    );
    return rows.map(MedicationOccurrence.fromMap).toList();
  }

  Future<void> markOccurrenceTaken(int occurrenceId) async {
    final changed = await (await _getDatabase()).update(
      'medication_occurrences',
      {
        'status': MedicationOccurrenceStatus.taken.name,
        'confirmed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
    if (changed == 0) {
      throw StateError('Cette prise est introuvable.');
    }
  }

  Future<void> postponeOccurrence({
    required int occurrenceId,
    required DateTime date,
    required String time,
  }) async {
    final normalizedTime = _normalizeTime(time);
    if (normalizedTime == null) {
      throw ArgumentError.value(time, 'time', 'Invalid medication time');
    }
    final database = await _getDatabase();
    final rows = await database.rawQuery(
      '''
      SELECT m.start_date, m.end_date
      FROM medication_occurrences o
      JOIN medications m ON m.id = o.medication_id
      WHERE o.id = ?
      ''',
      [occurrenceId],
    );
    if (rows.isEmpty) throw StateError('Cette prise est introuvable.');

    final selectedDate = _dateOnly(date);
    final startDate = DateTime.parse(rows.first['start_date'] as String);
    final endDate = rows.first['end_date'] == null
        ? null
        : DateTime.parse(rows.first['end_date'] as String);
    if (selectedDate.isBefore(_dateOnly(startDate)) ||
        (endDate != null && selectedDate.isAfter(_dateOnly(endDate)))) {
      throw ArgumentError.value(
        date,
        'date',
        'The postponed occurrence must remain within the treatment period.',
      );
    }

    final changed = await database.update(
      'medication_occurrences',
      {
        'status': MedicationOccurrenceStatus.postponed.name,
        'rescheduled_date': _dateToDatabase(selectedDate),
        'rescheduled_time': normalizedTime,
        'confirmed_at': null,
      },
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
    if (changed == 0) throw StateError('Cette prise est introuvable.');
  }

  Future<void> ignoreOccurrence(int occurrenceId) async {
    final changed = await (await _getDatabase()).update(
      'medication_occurrences',
      {'status': MedicationOccurrenceStatus.ignored.name, 'confirmed_at': null},
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
    if (changed == 0) {
      throw StateError('Cette prise est introuvable.');
    }
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null && database.isOpen) {
      await database.close();
    }
  }

  Future<sqflite.Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final factory = _databaseFactoryOverride ?? _platformDatabaseFactory();
    final databasePath = _databasePathOverride ?? await _getDatabasePath();
    _database = await factory.openDatabase(
      databasePath,
      options: sqflite.OpenDatabaseOptions(
        version: 4,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE medications (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              dosage TEXT NOT NULL,
              time TEXT NOT NULL,
              start_date TEXT NOT NULL,
              end_date TEXT,
              reminder_enabled INTEGER NOT NULL DEFAULT 1,
              active_ingredient TEXT,
              commercial_presentation TEXT,
              deleted_at TEXT
            )
          ''');
          await _createScheduleTables(database);
        },
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await database.execute(
              'ALTER TABLE medications ADD COLUMN active_ingredient TEXT',
            );
            await database.execute(
              'ALTER TABLE medications ADD COLUMN commercial_presentation TEXT',
            );
          }
          if (oldVersion < 3) {
            await database.execute('''
              CREATE TABLE medications_v3 (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                dosage TEXT NOT NULL,
                time TEXT NOT NULL,
                start_date TEXT NOT NULL,
                end_date TEXT,
                reminder_enabled INTEGER NOT NULL DEFAULT 1,
                active_ingredient TEXT,
                commercial_presentation TEXT
              )
            ''');
            await database.execute('''
              INSERT INTO medications_v3 (
                id, name, dosage, time, start_date, end_date,
                reminder_enabled, active_ingredient, commercial_presentation
              )
              SELECT id, name, dosage, time, start_date, end_date,
                reminder_enabled, active_ingredient, commercial_presentation
              FROM medications
            ''');
            await database.execute('DROP TABLE medications');
            await database.execute(
              'ALTER TABLE medications_v3 RENAME TO medications',
            );
            await _createScheduleTables(database);
            await _migrateLegacySchedules(database);
          }
          if (oldVersion < 4) {
            await database.execute(
              'ALTER TABLE medications ADD COLUMN deleted_at TEXT',
            );
          }
        },
      ),
    );
    return _database!;
  }

  Future<Medication> _loadMedication(
    sqflite.DatabaseExecutor database,
    Map<String, Object?> row,
  ) async {
    final medicationId = row['id'] as int;
    final rules = await database.query(
      'medication_schedules',
      columns: ['id', 'weekdays_mask'],
      where: 'medication_id = ?',
      whereArgs: [medicationId],
      limit: 1,
    );
    final rule = rules.isEmpty ? null : rules.first;
    final times = rule == null
        ? <Map<String, Object?>>[]
        : await database.query(
            'medication_schedule_times',
            columns: ['time'],
            where: 'schedule_id = ?',
            whereArgs: [rule['id']],
            orderBy: 'position, time',
          );
    return Medication.fromMap({
      ...row,
      'schedule_times': times.map((value) => value['time'] as String).toList(),
      'weekdays_mask': rule?['weekdays_mask'] as int? ?? 127,
    });
  }

  Map<String, Object?> _medicationValues(
    Medication medication,
    List<String> times,
  ) {
    final values = medication.toMap()..remove('id');
    values['time'] = times.first;
    return values;
  }

  List<String> _validatedTimes(Medication medication) {
    if (medication.weekdaysMask <= 0 || medication.weekdaysMask > 127) {
      throw ArgumentError.value(
        medication.weekdaysMask,
        'weekdaysMask',
        'Select at least one valid weekday.',
      );
    }
    if (medication.endDate != null &&
        _dateOnly(medication.endDate!)
            .isBefore(_dateOnly(medication.startDate))) {
      throw ArgumentError.value(
        medication.endDate,
        'endDate',
        'Must not precede startDate.',
      );
    }
    final suppliedTimes = medication.scheduleTimes.isEmpty
        ? [medication.time]
        : medication.scheduleTimes;
    final normalizedTimes = <String>[];
    for (final value in suppliedTimes) {
      final time = _normalizeTime(value);
      if (time == null) {
        throw ArgumentError.value(value, 'scheduleTimes', 'Invalid time.');
      }
      if (normalizedTimes.contains(time)) {
        throw ArgumentError.value(
          value,
          'scheduleTimes',
          'Duplicate medication times are not allowed.',
        );
      }
      normalizedTimes.add(time);
    }
    if (normalizedTimes.isEmpty) {
      throw ArgumentError.value(
        suppliedTimes,
        'scheduleTimes',
        'At least one time is required.',
      );
    }
    normalizedTimes.sort();
    return normalizedTimes;
  }

  Future<void> _saveSchedule(
    sqflite.Transaction transaction,
    int medicationId,
    int weekdaysMask,
    List<String> times,
  ) async {
    final rules = await transaction.query(
      'medication_schedules',
      columns: ['id'],
      where: 'medication_id = ?',
      whereArgs: [medicationId],
      limit: 1,
    );
    late final int scheduleId;
    if (rules.isEmpty) {
      scheduleId = await transaction.insert('medication_schedules', {
        'medication_id': medicationId,
        'weekdays_mask': weekdaysMask,
      });
    } else {
      scheduleId = rules.first['id'] as int;
      await transaction.update(
        'medication_schedules',
        {'weekdays_mask': weekdaysMask},
        where: 'id = ?',
        whereArgs: [scheduleId],
      );
      await transaction.delete(
        'medication_occurrences',
        where: 'schedule_id = ? AND scheduled_date >= ? AND status = ?',
        whereArgs: [scheduleId, _dateToDatabase(DateTime.now()), 'scheduled'],
      );
    }
    await transaction.delete(
      'medication_schedule_times',
      where: 'schedule_id = ?',
      whereArgs: [scheduleId],
    );
    for (var index = 0; index < times.length; index++) {
      await transaction.insert('medication_schedule_times', {
        'schedule_id': scheduleId,
        'time': times[index],
        'position': index,
      });
    }
  }

  Future<void> _createScheduleTables(sqflite.DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE medication_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL UNIQUE,
        weekdays_mask INTEGER NOT NULL DEFAULT 127
          CHECK (weekdays_mask BETWEEN 1 AND 127),
        FOREIGN KEY (medication_id) REFERENCES medications(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE medication_schedule_times (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        schedule_id INTEGER NOT NULL,
        time TEXT NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        UNIQUE (schedule_id, time),
        FOREIGN KEY (schedule_id) REFERENCES medication_schedules(id)
          ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE medication_occurrences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL,
        schedule_id INTEGER NOT NULL,
        scheduled_date TEXT NOT NULL,
        scheduled_time TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'scheduled'
          CHECK (status IN ('scheduled', 'taken', 'postponed', 'ignored')),
        confirmed_at TEXT,
        rescheduled_date TEXT,
        rescheduled_time TEXT,
        UNIQUE (schedule_id, scheduled_date, scheduled_time),
        FOREIGN KEY (medication_id) REFERENCES medications(id)
          ON DELETE CASCADE,
        FOREIGN KEY (schedule_id) REFERENCES medication_schedules(id)
          ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _migrateLegacySchedules(
    sqflite.DatabaseExecutor database,
  ) async {
    final medications = await database.query(
      'medications',
      columns: ['id', 'time'],
    );
    for (final medication in medications) {
      final scheduleId = await database.insert('medication_schedules', {
        'medication_id': medication['id'],
        'weekdays_mask': 127,
      });
      final legacyTime = (medication['time'] as String).trim();
      if (legacyTime.isEmpty) continue;
      await database.insert('medication_schedule_times', {
        'schedule_id': scheduleId,
        'time': _normalizeTime(legacyTime) ?? legacyTime,
        'position': 0,
      });
    }
  }

  String? _normalizeTime(String value) {
    final normalized = value
        .replaceAll('\u202f', ' ')
        .trim()
        .toUpperCase()
        .replaceAll('.', '');
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$')
        .firstMatch(normalized);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3);
    if (minute > 59) return null;
    if (meridiem != null) {
      if (hour < 1 || hour > 12) return null;
      hour %= 12;
      if (meridiem == 'PM') hour += 12;
    } else if (hour > 23) {
      return null;
    }
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _dateToDatabase(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  sqflite.DatabaseFactory _platformDatabaseFactory() {
    initPlatformDatabase();
    return sqflite.databaseFactory;
  }

  Future<String> _getDatabasePath() async {
    if (_databaseFactoryOverride != null) {
      throw StateError(
        'databasePath is required with a custom databaseFactory.',
      );
    }

    if (kIsWeb) {
      // sqflite_common_ffi_web stores files in IndexedDB using the database name.
      if (SupabaseConfig.isDemoMode) {
        return 'sahacare_medications_local_demo.db';
      }
      return 'sahacare_medications.db';
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
