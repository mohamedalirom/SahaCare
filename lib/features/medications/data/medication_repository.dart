import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../../core/database/platform_db/db_init.dart';
import '../../../core/config/supabase_config.dart';
import '../domain/entities/medication.dart';
import '../domain/entities/medication_occurrence.dart';
import '../domain/entities/medication_stock.dart';
import '../domain/services/medication_adherence.dart';
import '../domain/entities/medication_report.dart';
import 'services/medication_access.dart';
import 'services/medication_ownership_schema.dart';

class MedicationRepository {
  MedicationRepository({
    sqflite.DatabaseFactory? databaseFactory,
    String? databasePath,
    this.onChanged,
    MedicationAccess? access,
    this.allowIsolatedMigration = false,
  }) : _databaseFactoryOverride = databaseFactory,
       _databasePathOverride = databasePath,
       access = access ?? MedicationAccess.instance {
    if (allowIsolatedMigration &&
        (databaseFactory == null || databasePath == null)) {
      throw ArgumentError(
        'Une migration de test exige une base et une factory explicitement isolées.',
      );
    }
  }

  static final MedicationRepository instance = MedicationRepository();

  final sqflite.DatabaseFactory? _databaseFactoryOverride;
  final String? _databasePathOverride;
  sqflite.Database? _database;
  Future<sqflite.Database>? _opening;
  final MedicationAccess access;
  final bool allowIsolatedMigration;
  static final Object _leaseKey = Object();
  MedicationLease get _lease => Zone.current[_leaseKey] as MedicationLease;
  String get _owner {
    _lease.check();
    return _lease.owner;
  }

  Future<T> _scoped<T>(Future<T> Function() action) async {
    // Capture before the first await. An old form/request must never wait for
    // another account to log in and then adopt that account's identity.
    final lease = access.capture();
    return runZoned(() async {
      lease.check();
      try {
        final result = await action();
        lease.check();
        return result;
      } catch (_) {
        // Stale SQL/plugin errors can carry old medical arguments.
        lease.check();
        rethrow;
      }
    }, zoneValues: {_leaseKey: lease});
  }

  Future<T> _transaction<T>(
    sqflite.Database db,
    Future<T> Function(sqflite.Transaction) action,
  ) => db.transaction((tx) async {
    _lease.check();
    final result = await action(tx);
    _lease.check();
    return result;
  });

  Future<void> prepareStorage() => _scoped(() async {
    await _getDatabase();
  });

  Future<void> _requireOwnedMedication(
    sqflite.DatabaseExecutor db,
    int id,
  ) async {
    final rows = await db.query(
      'medications',
      columns: ['id'],
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, _owner],
      limit: 1,
    );
    _lease.check();
    if (rows.isEmpty) throw StateError('Traitement introuvable.');
  }

  Future<void> _requireOwnedOccurrence(
    sqflite.DatabaseExecutor db,
    int id,
  ) async {
    final rows = await db.rawQuery(
      '''SELECT o.id FROM medication_occurrences o
      JOIN medications m ON m.id=o.medication_id
      JOIN medication_schedules s ON s.id=o.schedule_id AND s.medication_id=m.id
      WHERE o.id=? AND m.owner_id=? LIMIT 1''',
      [id, _owner],
    );
    _lease.check();
    if (rows.isEmpty) throw StateError('Cette prise est introuvable.');
  }

  /// Called after a committed business mutation, never inside its transaction.
  Future<void> Function()? onChanged;

  Future<List<Medication>> getAll() => _scoped(() async {
    final database = await _getDatabase();
    final rows = await database.query(
      'medications',
      where: 'owner_id = ? AND deleted_at IS NULL',
      whereArgs: [_owner],
      orderBy: 'name COLLATE NOCASE',
    );
    final medications = <Medication>[];
    for (final row in rows) {
      medications.add(await _loadMedication(database, row));
    }
    return medications;
  });

  Future<Medication?> getById(int id) => _scoped(() async {
    final database = await _getDatabase();
    final rows = await database.query(
      'medications',
      where: 'id = ? AND owner_id = ? AND deleted_at IS NULL',
      whereArgs: [id, _owner],
      limit: 1,
    );
    return rows.isEmpty ? null : _loadMedication(database, rows.first);
  });

  Future<int> create(Medication medication) => _scoped(() async {
    final times = _validatedTimes(medication);
    final database = await _getDatabase();
    final result = await _transaction(database, (transaction) async {
      final id = await transaction.insert('medications', {
        ..._medicationValues(medication, times),
        'owner_id': _owner,
      });
      await _saveSchedule(transaction, id, medication.weekdaysMask, times);
      await _saveStockSettings(transaction, id, medication.stock);
      return id;
    });
    _lease.check();
    await onChanged?.call();
    return result;
  });

  Future<int> update(Medication medication) => _scoped(() async {
    final id = medication.id;
    if (id == null) {
      throw ArgumentError.value(id, 'medication.id', 'Must not be null');
    }
    final times = _validatedTimes(medication);
    final database = await _getDatabase();
    final result = await _transaction(database, (transaction) async {
      final changed = await transaction.update(
        'medications',
        _medicationValues(medication, times),
        where: 'id = ? AND owner_id = ? AND deleted_at IS NULL',
        whereArgs: [id, _owner],
      );
      if (changed == 0) return 0;
      await _saveSchedule(transaction, id, medication.weekdaysMask, times);
      await _saveStockSettings(transaction, id, medication.stock);
      return changed;
    });
    _lease.check();
    await onChanged?.call();
    return result;
  });

  Future<int> delete(int id) => _scoped(() async {
    final database = await _getDatabase();
    final result = await _transaction(database, (transaction) async {
      final deleted = await transaction.update(
        'medications',
        {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ? AND owner_id = ? AND deleted_at IS NULL',
        whereArgs: [id, _owner],
      );
      if (deleted == 0) return 0;
      await transaction.delete(
        'medication_occurrences',
        where: 'medication_id = ? AND status = ?',
        whereArgs: [id, MedicationOccurrenceStatus.scheduled.name],
      );
      return deleted;
    });
    _lease.check();
    await onChanged?.call();
    return result;
  });

  Future<int> ensureOccurrences({
    required DateTime from,
    required DateTime through,
  }) => _scoped(() async {
    final firstDay = _dateOnly(from);
    final lastDay = _dateOnly(through);
    if (lastDay.isBefore(firstDay)) {
      throw ArgumentError.value(through, 'through', 'Must not precede from');
    }

    final database = await _getDatabase();
    return _transaction(database, (transaction) async {
      final schedules = await transaction.rawQuery(
        '''
        SELECT s.id AS schedule_id, s.medication_id, s.weekdays_mask,
          m.start_date, m.end_date
        FROM medication_schedules s
        JOIN medications m ON m.id = s.medication_id
        WHERE m.owner_id = ? AND m.deleted_at IS NULL
          AND m.start_date <= ?
          AND (m.end_date IS NULL OR m.end_date >= ?)
      ''',
        [_owner, _dateToDatabase(lastDay), _dateToDatabase(firstDay)],
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
  });

  Future<List<MedicationOccurrence>> getOccurrences({
    required DateTime from,
    required DateTime through,
  }) => _scoped(() async {
    final database = await _getDatabase();
    final rows = await database.rawQuery(
      '''
      SELECT o.*, m.name AS medication_name, m.dosage AS medication_dosage,
        m.start_date AS medication_start_date,
        m.end_date AS medication_end_date,
        m.active_ingredient AS medication_active_ingredient
      FROM medication_occurrences o
      JOIN medications m ON m.id = o.medication_id
      JOIN medication_schedules scope_s ON scope_s.id=o.schedule_id AND scope_s.medication_id=m.id
      WHERE m.owner_id = ? AND COALESCE(o.rescheduled_date, o.scheduled_date) BETWEEN ? AND ?
        AND (
          m.deleted_at IS NULL
          OR COALESCE(o.rescheduled_date, o.scheduled_date) <= ?
        )
      ORDER BY COALESCE(o.rescheduled_date, o.scheduled_date),
        COALESCE(o.rescheduled_time, o.scheduled_time), m.name COLLATE NOCASE
    ''',
      [
        _owner,
        _dateToDatabase(from),
        _dateToDatabase(through),
        _dateToDatabase(DateTime.now()),
      ],
    );
    return rows.map(MedicationOccurrence.fromMap).toList();
  });

  /// Read-only: never backfills missing days or alters archived treatments.
  Future<List<AdherenceRecord>> getAdherenceRecords({
    required DateTime from,
    required DateTime through,
  }) => _scoped(() async {
    final database = await _getDatabase();
    return _readAdherenceRecords(database, from: from, through: through);
  });

  Future<List<AdherenceRecord>> _readAdherenceRecords(
    sqflite.DatabaseExecutor database, {
    required DateTime from,
    required DateTime through,
  }) async {
    final rows = await database.rawQuery(
      '''
      SELECT o.*, m.name AS medication_name, m.dosage AS medication_dosage,
        m.start_date AS medication_start_date, m.end_date AS medication_end_date,
        m.active_ingredient AS medication_active_ingredient, m.deleted_at AS archived_at
      FROM medication_occurrences o JOIN medications m ON m.id = o.medication_id
      JOIN medication_schedules scope_s ON scope_s.id=o.schedule_id AND scope_s.medication_id=m.id
      WHERE m.owner_id = ? AND COALESCE(o.rescheduled_date, o.scheduled_date) BETWEEN ? AND ?
      ORDER BY o.id
    ''',
      [_owner, _dateToDatabase(from), _dateToDatabase(through)],
    );
    return rows
        .map(
          (row) => AdherenceRecord(
            MedicationOccurrence.fromMap(row),
            archivedAt: row['archived_at'] == null
                ? null
                : DateTime.parse(row['archived_at'] as String),
          ),
        )
        .toList();
  }

  /// One consistent read transaction, without generating missing occurrences.
  Future<MedicationReportSnapshot> getReportSnapshot({
    required DateTime from,
    required DateTime through,
  }) => _scoped(() async {
    final database = await _getDatabase();
    return _transaction(database, (tx) async {
      final rows = await tx.query(
        'medications',
        where: 'owner_id = ?',
        whereArgs: [_owner],
        orderBy: 'name COLLATE NOCASE',
      );
      final treatments = <ReportTreatment>[];
      for (final row in rows) {
        treatments.add(
          ReportTreatment(
            await _loadMedication(tx, row),
            archivedAt: row['deleted_at'] == null
                ? null
                : DateTime.parse(row['deleted_at'] as String),
          ),
        );
      }
      return MedicationReportSnapshot(
        treatments: treatments,
        occurrences: await _readAdherenceRecords(
          tx,
          from: from,
          through: through,
        ),
      );
    });
  });

  Future<List<MedicationOccurrence>> getOccurrencesForMedication(
    int medicationId,
  ) => _scoped(() async {
    final database = await _getDatabase();
    final rows = await database.rawQuery(
      '''
      SELECT o.*, m.name AS medication_name, m.dosage AS medication_dosage,
        m.start_date AS medication_start_date,
        m.end_date AS medication_end_date,
        m.active_ingredient AS medication_active_ingredient
      FROM medication_occurrences o
      JOIN medications m ON m.id = o.medication_id
      JOIN medication_schedules scope_s ON scope_s.id=o.schedule_id AND scope_s.medication_id=m.id
      WHERE o.medication_id = ? AND m.owner_id = ?
      ORDER BY COALESCE(o.rescheduled_date, o.scheduled_date) DESC,
        COALESCE(o.rescheduled_time, o.scheduled_time) DESC
      ''',
      [medicationId, _owner],
    );
    return rows.map(MedicationOccurrence.fromMap).toList();
  });

  Future<void> markOccurrenceTaken(int occurrenceId) => _scoped(() async {
    final db = await _getDatabase();
    await _transaction(db, (tx) async {
      await _requireOwnedOccurrence(tx, occurrenceId);
      final rows = await tx.query(
        'medication_occurrences',
        where: 'id = ?',
        whereArgs: [occurrenceId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Cette prise est introuvable.');
      final occurrence = rows.single;
      if (occurrence['status'] == 'taken') return;
      final medicationId = occurrence['medication_id'] as int;
      final key =
          '$medicationId|${occurrence['scheduled_date']}|${occurrence['scheduled_time']}';
      final receipt = await tx.query(
        'medication_stock_movements',
        where: 'occurrence_key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (receipt.isEmpty) {
        final stock = await _loadStock(tx, medicationId);
        var kind = 'untracked_confirmation';
        var debit = 0;
        var required = 0;
        if (stock != null && stock.enabled) {
          required = stock.unitsPerDose.milliUnits;
          if (stock.remaining.milliUnits >= required) {
            debit = required;
            kind = 'consumption';
            await tx.update(
              'medication_stock',
              {'remaining_milli': stock.remaining.milliUnits - debit},
              where: 'medication_id = ?',
              whereArgs: [medicationId],
            );
          } else {
            // A real intake is recorded without a negative or partial debit.
            kind = 'anomaly';
          }
        }
        await _stockMovement(
          tx,
          medicationId,
          kind,
          -debit,
          quantityAfter: stock == null
              ? null
              : stock.remaining.milliUnits - debit,
          unit: stock?.unit,
          required: required,
          occurrenceKey: key,
        );
      }
      await tx.update(
        'medication_occurrences',
        {'status': 'taken', 'confirmed_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [occurrenceId],
      );
    });
    _lease.check();
    await onChanged?.call();
  });

  Future<List<StockMovement>> stockMovements(int medicationId) =>
      _scoped(() async {
        final database = await _getDatabase();
        await _requireOwnedMedication(database, medicationId);
        return (await (await _getDatabase()).rawQuery(
          '''
        SELECT m.*, CASE WHEN m.kind = 'anomaly' AND NOT EXISTS (
          SELECT 1 FROM medication_stock_movements r WHERE r.resolves_id = m.id
        ) THEN 1 ELSE 0 END AS unresolved
        FROM medication_stock_movements m WHERE medication_id = ?
        ORDER BY id DESC
      ''',
          [medicationId],
        )).map(StockMovement.fromMap).toList();
      });

  Future<void> replenishStock(int medicationId, StockQuantity quantity) =>
      _scoped(() async {
        final db = await _getDatabase();
        await _transaction(db, (tx) async {
          final stock = await _requireStock(tx, medicationId);
          stock.unit.validate(quantity);
          if (quantity.milliUnits <= 0) {
            throw ArgumentError('Ajoutez une quantité positive.');
          }
          final remaining = stock.remaining + quantity;
          await tx.update(
            'medication_stock',
            {
              'remaining_milli': remaining.milliUnits,
              'reference_milli':
                  remaining.milliUnits > stock.referenceQuantity.milliUnits
                  ? remaining.milliUnits
                  : stock.referenceQuantity.milliUnits,
            },
            where: 'medication_id = ?',
            whereArgs: [medicationId],
          );
          await _stockMovement(
            tx,
            medicationId,
            'replenishment',
            quantity.milliUnits,
            quantityAfter: remaining.milliUnits,
            unit: stock.unit,
          );
        });
        _lease.check();
        await onChanged?.call();
      });

  Future<void> correctStockQuantity(
    int medicationId,
    StockQuantity quantity, {
    required String reason,
    List<int> reconciledAnomalyIds = const [],
  }) => _scoped(() async {
    final db = await _getDatabase();
    await _transaction(db, (tx) async {
      final stock = await _requireStock(tx, medicationId);
      stock.unit.validate(quantity);
      if (quantity.milliUnits < 0 || reason.trim().isEmpty) {
        throw ArgumentError(
          'Une quantité non négative et un motif sont requis.',
        );
      }
      await tx.update(
        'medication_stock',
        {
          'remaining_milli': quantity.milliUnits,
          'reference_milli':
              quantity.milliUnits > stock.referenceQuantity.milliUnits
              ? quantity.milliUnits
              : stock.referenceQuantity.milliUnits,
        },
        where: 'medication_id = ?',
        whereArgs: [medicationId],
      );
      await _stockMovement(
        tx,
        medicationId,
        'correction',
        quantity.milliUnits - stock.remaining.milliUnits,
        quantityAfter: quantity.milliUnits,
        unit: stock.unit,
        note: reason.trim(),
      );
      for (final anomalyId in reconciledAnomalyIds.toSet()) {
        final anomaly = await _requireAnomaly(tx, medicationId, anomalyId);
        if (anomaly == null) continue;
        await _stockMovement(
          tx,
          medicationId,
          'inventory_reconciliation',
          0,
          quantityAfter: quantity.milliUnits,
          unit: stock.unit,
          resolvesId: anomalyId,
          required: anomaly['required_milli'] as int,
          note: 'Comptage physique incluant cette prise. ${reason.trim()}',
        );
      }
    });
    _lease.check();
    await onChanged?.call();
  });

  Future<void> resolveStockAnomaly(int medicationId, int anomalyId) =>
      _scoped(() async {
        final db = await _getDatabase();
        await _transaction(db, (tx) async {
          final stock = await _requireStock(tx, medicationId);
          final anomaly = await _requireAnomaly(tx, medicationId, anomalyId);
          if (anomaly == null) return; // Already resolved: idempotent.
          final required = anomaly['required_milli'] as int;
          if (stock.remaining.milliUnits < required) {
            throw StateError(
              'Stock insuffisant pour le débit complet. Corrigez la quantité ou réapprovisionnez.',
            );
          }
          final remaining = stock.remaining.milliUnits - required;
          await tx.update(
            'medication_stock',
            {'remaining_milli': remaining},
            where: 'medication_id = ?',
            whereArgs: [medicationId],
          );
          await _stockMovement(
            tx,
            medicationId,
            'resolution',
            -required,
            quantityAfter: remaining,
            unit: stock.unit,
            required: required,
            resolvesId: anomalyId,
          );
        });
        _lease.check();
        await onChanged?.call();
      });

  Future<Map<String, Object?>?> _requireAnomaly(
    sqflite.DatabaseExecutor db,
    int medicationId,
    int anomalyId,
  ) async {
    final rows = await db.query(
      'medication_stock_movements',
      where: "id = ? AND medication_id = ? AND kind = 'anomaly'",
      whereArgs: [anomalyId, medicationId],
    );
    if (rows.isEmpty) throw StateError('Anomalie introuvable.');
    final resolved = await db.query(
      'medication_stock_movements',
      where: 'resolves_id = ?',
      whereArgs: [anomalyId],
      limit: 1,
    );
    return resolved.isEmpty ? rows.single : null;
  }

  Future<MedicationStock> _requireStock(
    sqflite.DatabaseExecutor db,
    int medicationId,
  ) async {
    final medications = await db.query(
      'medications',
      columns: ['id'],
      where: 'id = ? AND owner_id = ? AND deleted_at IS NULL',
      whereArgs: [medicationId, _owner],
    );
    if (medications.isEmpty) {
      throw StateError('Traitement introuvable ou archivé.');
    }
    final stock = await _loadStock(db, medicationId);
    if (stock == null) {
      throw StateError('Configurez d’abord le suivi du stock.');
    }
    return stock;
  }

  Future<MedicationStock?> _loadStock(
    sqflite.DatabaseExecutor db,
    int medicationId,
  ) async {
    final rows = await db.query(
      'medication_stock',
      where: 'medication_id = ?',
      whereArgs: [medicationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final count = await db.rawQuery(
      '''
      SELECT COUNT(*) AS n FROM medication_stock_movements m
      WHERE medication_id = ? AND kind = 'anomaly' AND NOT EXISTS (
        SELECT 1 FROM medication_stock_movements r WHERE r.resolves_id = m.id
      )
    ''',
      [medicationId],
    );
    return MedicationStock.fromMap(
      rows.single,
      anomalies: count.single['n'] as int,
    );
  }

  Future<void> _stockMovement(
    sqflite.DatabaseExecutor db,
    int medicationId,
    String kind,
    int delta, {
    int? quantityAfter,
    StockUnit? unit,
    int required = 0,
    String? occurrenceKey,
    int? resolvesId,
    String? note,
  }) async {
    await db.insert('medication_stock_movements', {
      'medication_id': medicationId,
      'kind': kind,
      'delta_milli': delta,
      'quantity_after_milli': quantityAfter,
      'unit': unit?.name,
      'required_milli': required,
      'occurrence_key': occurrenceKey,
      'resolves_id': resolvesId,
      'created_at': DateTime.now().toIso8601String(),
      'note': note,
    });
  }

  Future<void> _saveStockSettings(
    sqflite.DatabaseExecutor db,
    int medicationId,
    MedicationStock? stock,
  ) async {
    if (stock == null) return;
    final old = await _loadStock(db, medicationId);
    if (old == null) {
      await db.insert('medication_stock', {
        'medication_id': medicationId,
        'enabled': stock.enabled ? 1 : 0,
        'unit': stock.unit.name,
        'initial_milli': stock.initialQuantity.milliUnits,
        'remaining_milli': stock.initialQuantity.milliUnits,
        'per_dose_milli': stock.unitsPerDose.milliUnits,
        'threshold_milli': stock.lowThreshold.milliUnits,
        'reference_milli': stock.initialQuantity.milliUnits,
      });
      await _stockMovement(
        db,
        medicationId,
        'initial',
        stock.initialQuantity.milliUnits,
        quantityAfter: stock.initialQuantity.milliUnits,
        unit: stock.unit,
      );
    } else {
      if (old.unit != stock.unit) {
        throw StateError(
          'L’unité du stock est fixe pour préserver son historique.',
        );
      }
      // Editing a stale form must not reset quantities changed by an intake.
      await db.update(
        'medication_stock',
        {
          'enabled': stock.enabled ? 1 : 0,
          'per_dose_milli': stock.unitsPerDose.milliUnits,
          'threshold_milli': stock.lowThreshold.milliUnits,
        },
        where: 'medication_id = ?',
        whereArgs: [medicationId],
      );
    }
  }

  Future<void> postponeOccurrence({
    required int occurrenceId,
    required DateTime date,
    required String time,
  }) => _scoped(() async {
    final normalizedTime = _normalizeTime(time);
    if (normalizedTime == null) {
      throw ArgumentError.value(time, 'time', 'Invalid medication time');
    }
    final database = await _getDatabase();
    await _transaction(database, (database) async {
      final rows = await database.rawQuery(
        '''
      SELECT m.start_date, m.end_date
      FROM medication_occurrences o
      JOIN medications m ON m.id = o.medication_id
      JOIN medication_schedules scope_s ON scope_s.id=o.schedule_id AND scope_s.medication_id=m.id
      WHERE o.id = ? AND m.owner_id = ?
      ''',
        [occurrenceId, _owner],
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

      await _requireOwnedOccurrence(database, occurrenceId);
      _lease.check();
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
    });
    _lease.check();
    await onChanged?.call();
  });

  Future<void> ignoreOccurrence(int occurrenceId) => _scoped(() async {
    final database = await _getDatabase();
    await _transaction(database, (database) async {
      await _requireOwnedOccurrence(database, occurrenceId);
      _lease.check();
      final changed = await database.update(
        'medication_occurrences',
        {
          'status': MedicationOccurrenceStatus.ignored.name,
          'confirmed_at': null,
        },
        where: 'id = ?',
        whereArgs: [occurrenceId],
      );
      if (changed == 0) {
        throw StateError('Cette prise est introuvable.');
      }
    });
    _lease.check();
    await onChanged?.call();
  });

  Future<List<Map<String, Object?>>> notificationRegistry() =>
      _scoped(() async {
        return (await _getDatabase()).query(
          'medication_notification_registry',
          where: 'owner_id = ?',
          whereArgs: [_owner],
        );
      });

  /// Durable IDs are reserved before calling the OS. A crash can be reconciled
  /// using these rows and the OS pending list on the next synchronization.
  Future<int> notificationId(String key) => _scoped(() async {
    final db = await _getDatabase();
    return _transaction(db, (transaction) async {
      await transaction.insert('medication_notification_registry', {
        'reminder_key': '$_owner|$key',
        'owner_id': _owner,
      }, conflictAlgorithm: sqflite.ConflictAlgorithm.ignore);
      final rows = await transaction.query(
        'medication_notification_registry',
        where: 'reminder_key = ? AND owner_id = ?',
        whereArgs: ['$_owner|$key', _owner],
        limit: 1,
      );
      final id = 1000000000 + (rows.single['id'] as int);
      if (id > 2147483647) throw StateError('Identifiants de rappel épuisés.');
      return id;
    });
  });

  Future<void> recordNotification(int systemId, String? signature) =>
      _scoped(() async {
        final changed = await (await _getDatabase()).update(
          'medication_notification_registry',
          {'signature': signature},
          where: 'id = ? AND owner_id = ?',
          whereArgs: [systemId - 1000000000, _owner],
        );
        if (changed == 0) throw StateError('Rappel introuvable.');
      });

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null && database.isOpen) {
      await database.close();
    }
  }

  Future<sqflite.Database> _getDatabase() async {
    _lease.check();
    if (_database != null) {
      return _database!;
    }
    final pending = _opening ??= _openDatabase();
    try {
      final db = await pending;
      _lease.check();
      return db;
    } finally {
      if (identical(_opening, pending)) _opening = null;
    }
  }

  Future<sqflite.Database> _openDatabase() async {
    _lease.check();

    final factory = _databaseFactoryOverride ?? _platformDatabaseFactory();
    final databasePath = _databasePathOverride ?? await _getDatabasePath();
    _lease.check();
    if (await factory.databaseExists(databasePath)) {
      final probe = await factory.openDatabase(
        databasePath,
        options: sqflite.OpenDatabaseOptions(
          readOnly: true,
          // Web has one SQLite instance/VFS and rejects multiple connections.
          // Serialize this read-only probe through the repository's _opening
          // future, close it, then open normally only after version approval.
          singleInstance: kIsWeb,
        ),
      );
      final version = await probe.getVersion();
      await probe.close();
      _lease.check();
      if (version != 7 && !allowIsolatedMigration) {
        throw MedicationMigrationRequired(version);
      }
      if (version > 7) throw MedicationMigrationRequired(version);
    }
    _database = await factory.openDatabase(
      databasePath,
      options: sqflite.OpenDatabaseOptions(
        version: 7,
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
          await _createNotificationRegistry(database);
          await _createStockTables(database);
          await addMedicationOwnershipSchema(database);
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
          if (oldVersion < 5) {
            await _createNotificationRegistry(database);
          }
          if (oldVersion < 6) {
            await _createStockTables(database);
            // Receipts, not retroactive consumption. Never debit old intakes.
            await database.execute('''
              INSERT INTO medication_stock_movements (
                medication_id, kind, delta_milli, required_milli,
                occurrence_key, created_at
              ) SELECT medication_id, 'legacy_confirmation', 0, 0,
                medication_id || '|' || scheduled_date || '|' || scheduled_time,
                COALESCE(confirmed_at, CURRENT_TIMESTAMP)
              FROM medication_occurrences WHERE status = 'taken'
            ''');
          }
          if (oldVersion < 7) {
            await addMedicationOwnershipSchema(database);
          }
        },
      ),
    );
    _lease.check();
    return _database!;
  }

  Future<void> _createStockTables(sqflite.DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE medication_stock (
        medication_id INTEGER PRIMARY KEY REFERENCES medications(id) ON DELETE RESTRICT,
        enabled INTEGER NOT NULL DEFAULT 0 CHECK (enabled IN (0, 1)),
        unit TEXT NOT NULL,
        initial_milli INTEGER NOT NULL CHECK (initial_milli >= 0),
        remaining_milli INTEGER NOT NULL CHECK (remaining_milli >= 0),
        per_dose_milli INTEGER NOT NULL CHECK (per_dose_milli > 0),
        threshold_milli INTEGER NOT NULL CHECK (threshold_milli >= 0),
        reference_milli INTEGER NOT NULL CHECK (reference_milli >= 0)
      )
    ''');
    await db.execute('''
      CREATE TABLE medication_stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE RESTRICT,
        kind TEXT NOT NULL CHECK (kind IN ('initial', 'consumption', 'replenishment',
          'correction', 'anomaly', 'resolution', 'inventory_reconciliation',
          'untracked_confirmation', 'legacy_confirmation')),
        delta_milli INTEGER NOT NULL,
        required_milli INTEGER NOT NULL DEFAULT 0 CHECK (required_milli >= 0),
        quantity_after_milli INTEGER CHECK (quantity_after_milli >= 0),
        unit TEXT,
        occurrence_key TEXT UNIQUE,
        resolves_id INTEGER UNIQUE REFERENCES medication_stock_movements(id) ON DELETE RESTRICT,
        created_at TEXT NOT NULL,
        note TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_stock_movements_medication ON medication_stock_movements(medication_id, id)',
    );
  }

  Future<void> _createNotificationRegistry(sqflite.DatabaseExecutor db) =>
      db.execute('''
        CREATE TABLE medication_notification_registry (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reminder_key TEXT NOT NULL UNIQUE,
          signature TEXT
        )
      ''');

  Future<Medication> _loadMedication(
    sqflite.DatabaseExecutor database,
    Map<String, Object?> row,
  ) async {
    final medicationId = row['id'] as int;
    await _requireOwnedMedication(database, medicationId);
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
      'stock': await _loadStock(database, medicationId),
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
