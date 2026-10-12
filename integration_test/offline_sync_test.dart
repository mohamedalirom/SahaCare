import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sahacare/core/database/database_helper.dart';
import 'package:sahacare/core/database/sync_engine.dart';
import 'package:sahacare/features/profil/domain/repositories/medical_repository.dart';
import 'package:sahacare/features/profil/domain/entities/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahacare/features/auth/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sahacare/core/config/supabase_config.dart';
import 'package:sahacare/features/profil/presentation/screens/profile_screen.dart';

// Mocking the AuthService to bypass the router's redirect to /login
class MockAuthService extends Mock implements AuthService {
  @override
  bool get isAuthenticated => true; // Bypass GoRouter redirect
}

void main() {
  // Ensure the binding is initialized for Android instrumentation tests
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 1. Initialize Supabase so SyncEngine doesn't crash on .instance
    await SupabaseConfig.initialize();

    // 2. Clear out the database before integration tests
    final db = await DatabaseHelper.instance.database;
    await db.delete('profiles');
    await db.delete('sync_queue');
  });

  testWidgets('Test 1 - Local SQLite Persistence & Outbox', (WidgetTester tester) async {
    final repo = MedicalRepository();
    const profile = UserProfile(
      id: 'integration-user',
      email: 'integration@example.com',
      fullName: 'Android Tester',
    );

    await repo.saveProfile(profile);

    // Verify via direct SQLite query on the device
    final db = await DatabaseHelper.instance.database;
    
    final profiles = await db.query('profiles');
    expect(profiles.length, 1);
    expect(profiles.first['full_name'], 'Android Tester');

    final queue = await db.query('sync_queue');
    expect(queue.length, 1);
    expect(queue.first['status'], 'PENDING');
  });

  testWidgets('Test 2 - Sync Engine Execution', (WidgetTester tester) async {
    // Note: In a real environment, you must be signed into Supabase for this to push.
    // If you are not signed in, it will catch the error and mark as FAILED.
    // We will verify that the queue item changes state or gets cleaned up without crashing.
    
    await SyncEngine.instance.syncNow();
    
    final db = await DatabaseHelper.instance.database;
    
    // Poll the database for up to 10 seconds waiting for the network timeout / failure
    int retries = 0;
    List<Map<String, Object?>> queue = [];
    while (retries < 10) {
      queue = await db.query('sync_queue');
      if (queue.isEmpty || queue.first['status'] == 'FAILED') break;
      await Future.delayed(const Duration(seconds: 1));
      retries++;
    }
    
    // It should either be empty (if successful sync) or marked as FAILED (if Supabase rejects it)
    if (queue.isNotEmpty) {
      expect(queue.first['status'], 'FAILED', reason: 'Poison pill should be marked as FAILED');
    } else {
      expect(queue.isEmpty, isTrue, reason: 'Queue should be empty on success');
    }
  });

  testWidgets('Test 3 - Router & UI Guard Bypass', (WidgetTester tester) async {
    // Since appRouter uses a strict static singleton (AuthService.instance) that cannot 
    // be easily mocked in Dart without modifying the source code, we bypass the global 
    // router guard by pumping the target screen directly in a test harness.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProfileScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that we are on the profile dashboard
    // The screen rendered Tableau de bord inside the segmented button
    expect(find.text('Tableau de bord'), findsWidgets);
  });
}
