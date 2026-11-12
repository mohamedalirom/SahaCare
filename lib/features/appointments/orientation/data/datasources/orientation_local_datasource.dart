import 'package:sqflite/sqflite.dart';
import 'package:sahacare/core/database/database_helper.dart';
import '../models/orientation_history_entry.dart';

abstract class OrientationLocalDataSource {
  Future<List<String>> getAllowedSpecialties();
  Future<void> saveHistory(OrientationHistoryEntry entry);
  Future<List<OrientationHistoryEntry>> getHistory();
  Future<void> clearHistory();
}

class OrientationLocalDataSourceImpl implements OrientationLocalDataSource {
  final Database? databaseOverride;

  OrientationLocalDataSourceImpl({this.databaseOverride});

  Future<Database> get _db async {
    if (databaseOverride != null) {
      return databaseOverride!;
    }
    return await DatabaseHelper.instance.database;
  }

  @override
  Future<List<String>> getAllowedSpecialties() async {
    final db = await _db;
    final specialties = <String>{};

    try {
      // 1. Lire depuis la table 'specialties'
      final specRows = await db.query('specialties', columns: ['name']);
      for (final row in specRows) {
        final name = row['name'] as String?;
        if (name != null && name.trim().isNotEmpty && name != 'Toutes') {
          specialties.add(name.trim());
        }
      }
    } catch (_) {
      // Table peut ne pas exister encore sur un ancien schéma
    }

    try {
      // 2. Lire les spécialités existantes dans le carnet de médecins
      final docRows = await db.rawQuery(
          "SELECT DISTINCT specialty FROM doctors WHERE specialty IS NOT NULL AND specialty != ''");
      for (final row in docRows) {
        final spec = row['specialty'] as String?;
        if (spec != null && spec.trim().isNotEmpty && spec != 'Toutes') {
          specialties.add(spec.trim());
        }
      }
    } catch (_) {}

    // Fallback de sécurité si la base est totalement vierge
    if (specialties.isEmpty) {
      specialties.addAll([
        'Médecine Générale',
        'Cardiologie',
        'Dermatologie',
        'Pédiatrie',
        'Ophtalmologie',
        'Dentiste',
        'Gynécologie',
        'Neurologie',
        'Orthopédie',
        'Psychiatrie',
      ]);
    }

    final list = specialties.toList();
    list.sort();
    return list;
  }

  @override
  Future<void> saveHistory(OrientationHistoryEntry entry) async {
    final db = await _db;
    try {
      await db.insert(
        'orientation_history',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  @override
  Future<List<OrientationHistoryEntry>> getHistory() async {
    final db = await _db;
    try {
      final rows = await db.query(
        'orientation_history',
        orderBy: 'date DESC',
      );
      return rows.map((r) => OrientationHistoryEntry.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> clearHistory() async {
    final db = await _db;
    try {
      await db.delete('orientation_history');
    } catch (_) {}
  }
}
