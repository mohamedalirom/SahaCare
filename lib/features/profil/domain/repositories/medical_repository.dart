import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/sync_engine.dart';
import '../entities/medical_history.dart';
import '../entities/user_profile.dart';

class MedicalRepository {
  final _uuid = const Uuid();

  /// Retrieves the user profile from the local SQLite database.
  /// Never hits Supabase directly; ensuring immediate UI responsiveness.
  Future<UserProfile?> getProfile(String userId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (maps.isNotEmpty) {
      return UserProfile.fromMap(maps.first, email: maps.first['email'] as String? ?? '');
    }
    return null;
  }

  /// Updates or inserts a profile locally, queuing it for background sync.
  Future<void> saveProfile(UserProfile profile) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Convert to map and inject local timestamp for Last-Write-Wins
    final payload = profile.toMap();
    payload['updated_at'] = now;
    
    // Ensure email is saved in sqflite payload for local UI hydration
    payload['email'] = profile.email;

    await db.transaction((txn) async {
      // 1. Update the local SQLite source of truth immediately
      await txn.insert(
        'profiles',
        payload,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Queue the mutation into the Outbox
      await txn.insert('sync_queue', {
        'id': _uuid.v4(),
        'operation': 'UPDATE',
        'table_name': 'profiles',
        'payload': jsonEncode(payload),
        'status': 'PENDING',
        'created_at': now,
      });
    });

    // Attempt to sync immediately without blocking the UI thread
    SyncEngine.instance.syncNow();
  }

  /// Updates profile visibility to doctors in the local SQLite table
  /// and queues a PENDING mutation into sync_queue for offline sync.
  Future<void> updateProfileVisibility(String userId, bool isVisible) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // 1. Update the local SQLite source of truth immediately
      final updated = await txn.update(
        'profiles',
        {
          'is_visible_to_doctors': isVisible ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      // If profile row doesn't exist yet locally, insert a minimal row
      if (updated == 0) {
        await txn.insert(
          'profiles',
          {
            'id': userId,
            'is_visible_to_doctors': isVisible ? 1 : 0,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 2. Queue the mutation into the Outbox
      await txn.insert('sync_queue', {
        'id': _uuid.v4(),
        'operation': 'UPDATE',
        'table_name': 'profiles',
        'payload': jsonEncode({
          'id': userId,
          'is_visible_to_doctors': isVisible,
          'updated_at': now,
        }),
        'status': 'PENDING',
        'created_at': now,
      });
    });

    // Attempt background sync without blocking the UI thread
    SyncEngine.instance.syncNow();
  }

  /// Retrieves the current profile visibility from local SQLite.
  Future<bool> getProfileVisibility(String userId) async {
    final db = await DatabaseHelper.instance.database;
    try {
      final rows = await db.query(
        'profiles',
        columns: ['is_visible_to_doctors'],
        where: 'id = ?',
        whereArgs: [userId],
      );
      if (rows.isNotEmpty && rows.first['is_visible_to_doctors'] != null) {
        final val = rows.first['is_visible_to_doctors'];
        return val == 1 || val == true;
      }
    } catch (_) {}
    return true; // Default to true if not specified
  }

  /// Retrieves allergies from the local database.
  Future<List<Map<String, dynamic>>> getAllergies(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'allergies',
      where: 'profile_id = ?',
      whereArgs: [userId],
    );
  }

  /// Retrieves diseases from the local database.
  Future<List<Map<String, dynamic>>> getDiseases(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'diseases',
      where: 'profile_id = ?',
      whereArgs: [userId],
    );
  }

  /// Retrieves the medical history (antécédents) from the local database.
  Future<List<Map<String, dynamic>>> getHistoryEntries(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'medical_history',
      where: 'profile_id = ?',
      whereArgs: [userId],
    );
  }

  /// Whole medical record, always served from SQLite (instant, offline-safe).
  Future<MedicalHistory> getMedicalHistory(String userId) async {
    final results = await Future.wait([
      getDiseases(userId),
      getAllergies(userId),
      getHistoryEntries(userId),
    ]);
    return MedicalHistory(
      diseases: results[0].map(Disease.fromMap).toList(growable: false),
      allergies: results[1].map(Allergy.fromMap).toList(growable: false),
      history: results[2].map(MedicalHistoryEntry.fromMap).toList(growable: false),
    );
  }

  // ---------------------------------------------------------------------------
  // Diseases (Local SQLite only)
  // ---------------------------------------------------------------------------

  /// Creates a disease (client-side UUID v4) in local SQLite only.
  Future<Disease> addDisease(
    String userId, {
    required String name,
    DateTime? diagnosedAt,
    bool isChronic = false,
  }) async {
    final disease = Disease(id: _uuid.v4(), name: name.trim(), diagnosedAt: diagnosedAt, isChronic: isChronic);
    await _insertLocal('diseases', userId, disease.toMap());
    return disease;
  }

  Future<void> updateDisease(String userId, Disease disease) =>
      _updateLocal('diseases', userId, disease.toMap());

  Future<void> deleteDisease(String userId, String id) => _deleteLocal('diseases', userId, id);

  // ---------------------------------------------------------------------------
  // Allergies (Local SQLite only)
  // ---------------------------------------------------------------------------

  Future<Allergy> addAllergy(
    String userId, {
    required String name,
    AllergySeverity severity = AllergySeverity.mild,
    AllergyKind kind = AllergyKind.other,
  }) async {
    final allergy = Allergy(id: _uuid.v4(), name: name.trim(), severity: severity, kind: kind);
    await _insertLocal('allergies', userId, allergy.toMap());
    return allergy;
  }

  Future<void> updateAllergy(String userId, Allergy allergy) =>
      _updateLocal('allergies', userId, allergy.toMap());

  Future<void> deleteAllergy(String userId, String id) => _deleteLocal('allergies', userId, id);

  // ---------------------------------------------------------------------------
  // Medical history / Antécédents (Local SQLite only)
  // ---------------------------------------------------------------------------

  Future<MedicalHistoryEntry> addHistoryEntry(
    String userId, {
    required String title,
    String description = '',
    DateTime? date,
  }) async {
    final entry = MedicalHistoryEntry(id: _uuid.v4(), title: title.trim(), description: description.trim(), date: date);
    await _insertLocal('medical_history', userId, entry.toMap());
    return entry;
  }

  Future<void> updateHistoryEntry(String userId, MedicalHistoryEntry entry) =>
      _updateLocal('medical_history', userId, entry.toMap());

  Future<void> deleteHistoryEntry(String userId, String id) => _deleteLocal('medical_history', userId, id);

  // ---------------------------------------------------------------------------
  // Local SQLite helpers (Privacy-first: strictly local, no sync_queue outbox)
  // ---------------------------------------------------------------------------

  Future<void> _insertLocal(String table, String userId, Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = <String, dynamic>{...row, 'profile_id': userId, 'updated_at': now};
    await db.insert(table, payload, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _updateLocal(String table, String userId, Map<String, dynamic> row) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = <String, dynamic>{...row, 'profile_id': userId, 'updated_at': now};
    await db.update(table, payload, where: 'id = ? AND profile_id = ?', whereArgs: [row['id'], userId]);
  }

  Future<void> _deleteLocal(String table, String userId, String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(table, where: 'id = ? AND profile_id = ?', whereArgs: [id, userId]);
  }
}
