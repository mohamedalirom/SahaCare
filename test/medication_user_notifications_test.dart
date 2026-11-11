import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/data/services/medication_access.dart';
import 'package:sahacare/features/medications/data/services/medication_notification_service.dart';
import 'package:sahacare/features/medications/data/services/medication_notification_backend.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/services/medication_reminder_planner.dart';

import 'helpers/medication_test_access.dart';

class _Backend implements MedicationNotificationBackend {
  final requests = <int, PendingMedicationNotification>{};
  final cancelled = <int>[];
  bool failCancel = false, hidePending = false;
  Future<void> Function()? afterSchedule;
  @override
  bool get supported => true;
  @override
  bool get isIOS => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<MedicationNotificationPermission> permissions({
    bool request = false,
    bool requestExact = false,
  }) async =>
      const MedicationNotificationPermission(allowed: true, exact: true);
  @override
  Future<tz.Location> location() async => tz.getLocation('Europe/Paris');
  @override
  Future<List<PendingMedicationNotification>> pending() async =>
      hidePending ? [] : requests.values.toList();
  @override
  Future<void> cancel(int id) async {
    if (failCancel) throw StateError('simulated');
    cancelled.add(id);
    requests.remove(id);
  }

  @override
  Future<void> schedule(
    int id,
    MedicationReminder reminder, {
    required bool exact,
  }) async {
    requests[id] = PendingMedicationNotification(id, reminder.payload);
    await afterSchedule?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    data.initializeTimeZones();
  });
  late TestMedicationAuthority source;
  late MedicationAccess access;
  late MedicationRepository repo;
  late _Backend backend;
  late TestMedicationCleanupStore store;
  late MedicationNotificationService service;
  final now = DateTime.utc(2030, 1, 7, 6);
  Future<void> user(String? owner) async {
    source.owner = owner;
    source.revision++;
    await access.refresh();
  }

  Future<void> create(String name) async {
    await repo.create(
      Medication(
        name: name,
        dosage: 'fictif',
        time: '08:00',
        startDate: DateTime(2030, 1, 7),
        endDate: DateTime(2030, 1, 8),
        reminderEnabled: true,
      ),
    );
  }

  MedicationNotificationService makeService() => MedicationNotificationService(
    repository: repo,
    backend: backend,
    cleanupStore: store,
    now: () => now,
  );
  setUp(() {
    source = TestMedicationAuthority(owner: 'supabase:fixture:A', demo: false);
    access = MedicationAccess(authority: source);
    repo = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      access: access,
    );
    backend = _Backend();
    store = TestMedicationCleanupStore();
    service = makeService();
  });
  tearDown(() async {
    service.dispose();
    await repo.close();
    access.dispose();
  });
  test(
    'account transition cancels A before scheduling B; unrelated module intact',
    () async {
      await create('Fictif A');
      await service.synchronize();
      final aIds = backend.requests.keys.toSet();
      final aPayloads = backend.requests.values.map((p) => p.payload).toSet();
      backend.requests[55] = const PendingMedicationNotification(
        55,
        'other.module',
      );
      await user('supabase:fixture:B');
      await create('Fictif B');
      await service.synchronize();
      expect(aIds.every(backend.cancelled.contains), isTrue);
      expect(backend.requests.containsKey(55), isTrue);
      final b = backend.requests.values.where((p) => p.id != 55);
      expect(b, isNotEmpty);
      expect(b.every((p) => !aPayloads.contains(p.payload)), isTrue);
      expect(
        b.every(
          (p) =>
              !p.payload!.contains('supabase:') &&
              !p.payload!.contains('Fictif'),
        ),
        isTrue,
      );
      await user(null);
      await service.synchronize();
      expect(backend.requests.keys, [55]);
      expect(service.value.count, 0);
    },
  );
  test(
    'cancellation failure never announces successful synchronization under B',
    () async {
      await create('Fictif A');
      await service.synchronize();
      final ids = backend.requests.keys.toSet();
      await user('supabase:fixture:B');
      await create('Fictif B');
      backend.failCancel = true;
      await service.synchronize();
      expect(service.value.status, MedicationNotificationStatus.error);
      expect(service.value.count, 0);
      expect(backend.requests.keys.toSet(), ids);
      backend.failCancel = false;
      await service.synchronize();
      expect(service.value.status, MedicationNotificationStatus.scheduled);
      expect(backend.requests.keys.toSet().intersection(ids), isEmpty);
    },
  );
  test(
    'logout while OS schedules invalidates the job and cancels its new request',
    () async {
      await create('Fictif A');
      backend.afterSchedule = () async {
        backend.afterSchedule = null;
        await user(null);
      };
      await service.synchronize();
      expect(backend.requests, isEmpty);
      expect(service.value.count, 0);
      expect(
        service.value.status,
        isNot(MedicationNotificationStatus.scheduled),
      );
    },
  );
  test('durable opaque IDs clean old requests after restart even when pending list is empty', () async {
    await create('Fictif A');
    await service.synchronize();
    final old = Set<int>.of(store.ids);
    expect(old, isNotEmpty);
    service.dispose();
    await user('supabase:fixture:B');
    backend.hidePending = true;
    service = makeService();
    await service.synchronize();
    expect(old.every(backend.cancelled.contains), isTrue);
    expect(backend.requests, isEmpty);
  });
  test(
    'started service observes logout without visiting medication screens again',
    () async {
      await create('Fictif A');
      service.start();
      await service.synchronize();
      expect(backend.requests, isNotEmpty);
      await user(null);
      await service.synchronize();
      expect(backend.requests, isEmpty);
      expect(service.value.count, 0);
    },
  );
}
