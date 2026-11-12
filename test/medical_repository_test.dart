import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sahacare/core/database/database_helper.dart';
import 'package:sahacare/features/profil/domain/repositories/medical_repository.dart';
import 'package:sahacare/features/profil/domain/entities/user_profile.dart';

void main() {
  setUpAll(() {
    // Initialize FFI for local desktop tests
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    // Clean up local databases after each test
    final db = await DatabaseHelper.instance.database;
    await db.delete('profiles');
    await db.delete('sync_queue');
  });

  test('saveProfile inserts into profiles AND sync_queue simultaneously', () async {
    final repo = MedicalRepository();
    const profile = UserProfile(
      id: 'test-user-123',
      email: 'test@example.com',
      fullName: 'John Doe',
    );

    // 1. Execute the local save (Offline)
    await repo.saveProfile(profile);

    final db = await DatabaseHelper.instance.database;
    
    // 2. Verify Local Schema (Source of Truth)
    final profileRows = await db.query('profiles');
    expect(profileRows.length, 1, reason: 'Profile must be saved locally');
    expect(profileRows.first['id'], 'test-user-123');
    expect(profileRows.first['full_name'], 'John Doe');
    expect(profileRows.first['updated_at'], isNotNull);

    // 3. Verify Outbox Queue
    final queueRows = await db.query('sync_queue');
    expect(queueRows.length, 1, reason: 'Outbox queue must contain 1 item');
    
    final item = queueRows.first;
    expect(item['operation'], 'UPDATE');
    expect(item['table_name'], 'profiles');
    expect(item['status'], 'PENDING');
    
    // Ensure Client-Side UUIDs are strictly valid UUID v4
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', 
      caseSensitive: false
    );
    expect(uuidRegex.hasMatch(item['id'] as String), isTrue, reason: 'Queue ID must be a valid UUID v4');
  });
}
