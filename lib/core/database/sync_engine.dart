import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class SyncEngine {
  static final SyncEngine instance = SyncEngine._init();
  SyncEngine._init();

  bool _isSyncing = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  void initialize() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        syncNow();
      }
    });
    // Trigger an initial sync check
    syncNow();
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.isEmpty || connectivityResult.first == ConnectivityResult.none) {
        return; // Offline
      }

      await _pushOutbox();
      await _pullUpdates();
    } finally {
      _isSyncing = false;
    }
  }

  /// Pushes local mutations to Supabase (Outbox Pattern) in FIFO order
  Future<void> _pushOutbox() async {
    final db = await DatabaseHelper.instance.database;
    final queue = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'created_at ASC',
    );

    for (final item in queue) {
      final String id = item['id'] as String;
      final String operation = item['operation'] as String;
      final String tableName = item['table_name'] as String;
      final Map<String, dynamic> payload = jsonDecode(item['payload'] as String);

      // Strictly sync profile data. If any legacy medical mutations exist in the queue, purge them.
      if (tableName != 'profiles') {
        await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
        continue;
      }

      try {
        // Strip out local-only fields that Supabase might reject if they don't exist in the backend schema
        final supabasePayload = Map<String, dynamic>.from(payload);
        supabasePayload.remove('email'); // Managed by auth, not profiles table usually
        
        // For updated_at, convert integer timestamp back to iso8601 if backend expects timestamps
        if (supabasePayload.containsKey('updated_at') && supabasePayload['updated_at'] is int) {
           supabasePayload['updated_at'] = DateTime.fromMillisecondsSinceEpoch(supabasePayload['updated_at'] as int).toIso8601String();
        }

        if (operation == 'INSERT' || operation == 'UPDATE') {
          // Supabase upsert is perfect here
          await Supabase.instance.client
              .from(tableName)
              .upsert(supabasePayload);
        } else if (operation == 'DELETE') {
          await Supabase.instance.client
              .from(tableName)
              .delete()
              .eq('id', payload['id']);
        }
        
        // Success: Remove from queue
        await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        // Poison Pill handling: Mark as failed so it doesn't block the queue
        await db.update(
          'sync_queue',
          {'status': 'FAILED'},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  /// Pulls remote updates from Supabase using Last Write Wins
  /// Strictly pulls profile data. Medical tables (allergies, diseases, medical_history) are strictly local-only.
  Future<void> _pullUpdates() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    final db = await DatabaseHelper.instance.database;

    // Pull profile data only
    await _pullTable(db, 'profiles', 'id', user.id);
  }

  Future<void> _pullTable(Database db, String tableName, String key, String value) async {
    try {
      final response = await Supabase.instance.client
          .from(tableName)
          .select()
          .eq(key, value)
          .maybeSingle();
      
      if (response != null) {
        await _resolveConflictAndSave(db, tableName, response);
      }
    } catch (_) {}
  }

  Future<void> _resolveConflictAndSave(Database db, String tableName, Map<String, dynamic> remoteRow) async {
    final remoteUpdatedAt = _parseTimestamp(remoteRow['updated_at']);
    
    final localRows = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [remoteRow['id']],
      limit: 1,
    );

    // Format row for local SQLite schema
    final insertRow = Map<String, dynamic>.from(remoteRow);
    insertRow['updated_at'] = remoteUpdatedAt; // Store as integer timestamp locally
    // SQLite has no boolean type.
    insertRow.updateAll((_, v) => v is bool ? (v ? 1 : 0) : v);

    if (localRows.isEmpty) {
      // Doesn't exist locally -> insert
      await db.insert(tableName, insertRow, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      // Exists locally -> compare updated_at (Last Write Wins)
      final localUpdatedAt = localRows.first['updated_at'] as int? ?? 0;
      if (remoteUpdatedAt > localUpdatedAt) {
        await db.update(
          tableName,
          insertRow,
          where: 'id = ?',
          whereArgs: [remoteRow['id']],
        );
      }
    }
  }

  int _parseTimestamp(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is String) {
      final date = DateTime.tryParse(val);
      if (date != null) return date.millisecondsSinceEpoch;
    }
    return 0;
  }

  void dispose() {
    _connectivitySubscription.cancel();
  }
}
