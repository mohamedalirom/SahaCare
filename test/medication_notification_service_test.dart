import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/data/services/medication_notification_backend.dart';
import 'package:sahacare/features/medications/data/services/medication_notification_service.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/services/medication_reminder_planner.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_notification_panel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

class _Backend implements MedicationNotificationBackend {
  @override
  bool supported = true;
  @override
  bool isIOS = false;
  bool allowed = true;
  bool exact = true;
  bool failSchedule = false;
  bool failCancel = false;
  String zone = 'Europe/Paris';
  int initialized = 0;
  int scheduled = 0;
  bool permissionRequested = false;
  final requests = <int, PendingMedicationNotification>{};
  final dates = <int, DateTime>{};
  final cancelled = <int>[];
  @override
  Future<void> initialize() async {
    initialized++;
  }

  @override
  Future<tz.Location> location() async => tz.getLocation(zone);
  @override
  Future<MedicationNotificationPermission> permissions({
    bool request = false,
    bool requestExact = false,
  }) async {
    permissionRequested = permissionRequested || request;
    return MedicationNotificationPermission(allowed: allowed, exact: exact);
  }

  @override
  Future<List<PendingMedicationNotification>> pending() async =>
      requests.values.toList();
  @override
  Future<void> cancel(int id) async {
    if (failCancel) throw StateError('Injected cancellation failure');
    cancelled.add(id);
    requests.remove(id);
    dates.remove(id);
  }

  @override
  Future<void> schedule(
    int id,
    MedicationReminder reminder, {
    required bool exact,
  }) async {
    if (failSchedule) throw StateError('Injected scheduling failure');
    scheduled++;
    requests[id] = PendingMedicationNotification(id, reminder.payload);
    dates[id] = reminder.at;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    data.initializeTimeZones();
  });
  late MedicationRepository repo;
  late _Backend backend;
  late MedicationNotificationService service;
  final now = DateTime.utc(2030, 1, 7, 6);
  Medication treatment({
    List<String> times = const ['09:00', '18:00'],
    DateTime? end,
  }) => Medication(
    name: 'Médicament privé',
    dosage: 'Privé',
    time: times.first,
    scheduleTimes: times,
    startDate: DateTime(2030, 1, 7),
    endDate: end ?? DateTime(2030, 1, 8),
    reminderEnabled: true,
  );
  setUp(() {
    repo = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    backend = _Backend();
    service = MedicationNotificationService(
      repository: repo,
      backend: backend,
      now: () => now,
    );
    repo.onChanged = service.synchronize;
  });
  tearDown(() async {
    repo.onChanged = null;
    service.dispose();
    await repo.close();
  });

  test(
    'create commits SQLite then schedules with durable IDs and no duplicates',
    () async {
      await repo.create(treatment());
      expect(service.value.status, MedicationNotificationStatus.scheduled);
      expect(backend.requests.length, 4);
      expect((await repo.notificationRegistry()).length, 4);
      await Future.wait([service.synchronize(), service.synchronize()]);
      expect(backend.scheduled, 4);
      expect(
        backend.requests.values.every((e) => !e.payload!.contains('privé')),
        isTrue,
      );
    },
  );

  test(
    'editing cancels obsolete times; disabling and archiving cancel all',
    () async {
      final id = await repo.create(treatment());
      final oldIds = backend.requests.keys.toSet();
      final medication = (await repo.getById(id))!;
      await repo.update(medication.copyWith(scheduleTimes: ['11:00']));
      expect(backend.requests.length, 2);
      expect(backend.cancelled.toSet().containsAll(oldIds), isTrue);
      expect(backend.dates.values.every((e) => e.hour == 11), isTrue);
      await repo.update(medication.copyWith(reminderEnabled: false));
      expect(backend.requests, isEmpty);
      await repo.update(medication);
      expect(backend.requests.length, 4);
      await repo.delete(id);
      expect(backend.requests, isEmpty);
      expect(await repo.getById(id), isNull);
    },
  );

  test(
    'report, confirmation and ignored occurrence update OS requests',
    () async {
      final id = await repo.create(treatment());
      await repo.ensureOccurrences(
        from: DateTime(2030, 1, 7),
        through: DateTime(2030, 1, 8),
      );
      final doses = await repo.getOccurrencesForMedication(id);
      final dose = doses.firstWhere(
        (e) => e.scheduledDate.day == 7 && e.scheduledTime == '09:00',
      );
      await repo.postponeOccurrence(
        occurrenceId: dose.id,
        date: DateTime(2030, 1, 7),
        time: '11:00',
      );
      expect(
        backend.dates.values.any((e) => e.day == 7 && e.hour == 11),
        isTrue,
      );
      expect(
        backend.dates.values.any((e) => e.day == 7 && e.hour == 9),
        isFalse,
      );
      await repo.markOccurrenceTaken(dose.id);
      expect(backend.requests.length, 3);
      await repo.ignoreOccurrence(doses.firstWhere((e) => e.id != dose.id).id);
      expect(backend.requests.length, 2);
    },
  );

  test('new end date and timezone replace only affected requests', () async {
    final id = await repo.create(treatment());
    final before = Map<int, DateTime>.from(backend.dates);
    backend.zone = 'America/New_York';
    await service.synchronize();
    expect(backend.dates.keys.toSet(), before.keys.toSet());
    expect(
      backend.dates.values.first.toUtc(),
      isNot(before.values.first.toUtc()),
    );
    await repo.update(
      (await repo.getById(id))!.copyWith(endDate: DateTime(2030, 1, 7)),
    );
    expect(backend.requests.length, 2);
    expect(backend.dates.values.every((e) => e.day == 7), isTrue);
  });

  test(
    'permission refusal preserves treatment and cancels only medication IDs',
    () async {
      await repo.create(treatment());
      backend.requests[42] = const PendingMedicationNotification(
        42,
        'another-module',
      );
      backend.allowed = false;
      await service.synchronize();
      expect(service.value.status, MedicationNotificationStatus.denied);
      expect(backend.requests.keys, [42]);
      expect((await repo.getAll()).length, 1);
      expect(backend.permissionRequested, isFalse);
      backend.allowed = true;
      await service.synchronize(requestPermission: true);
      expect(backend.permissionRequested, isTrue);
      expect(backend.requests.length, 5);
    },
  );

  test(
    'schedule failure is visible, persisted IDs allow a successful retry',
    () async {
      backend.failSchedule = true;
      await repo.create(treatment());
      expect(service.value.status, MedicationNotificationStatus.error);
      expect((await repo.getAll()).length, 1);
      expect((await repo.notificationRegistry()).length, 4);
      backend.failSchedule = false;
      await service.synchronize();
      expect(backend.requests.length, 4);
      expect(service.value.status, MedicationNotificationStatus.scheduled);
    },
  );

  test(
    'cancellation failure retains its journal and is repaired on retry',
    () async {
      final id = await repo.create(treatment());
      backend.failCancel = true;
      await repo.delete(id);
      expect(service.value.status, MedicationNotificationStatus.error);
      expect(backend.requests.length, 4);
      backend.failCancel = false;
      await service.synchronize();
      expect(backend.requests, isEmpty);
      expect(
        (await repo.notificationRegistry()).every(
          (e) => e['signature'] == null,
        ),
        isTrue,
      );
    },
  );

  test('restart reconciles missing OS requests and a partial journal acknowledgement', () async {
    await repo.create(treatment());
    final id = backend.requests.keys.first;
    backend.requests.remove(id);
    await repo.recordNotification(backend.requests.keys.first, null);
    await service.synchronize();
    expect(backend.requests.length, 4);
    expect(backend.scheduled, 6);
  });

  test(
    'iOS reserves capacity for other modules and reports finite coverage',
    () async {
      backend.isIOS = true;
      for (var i = 1; i <= 8; i++) {
        backend.requests[i] = PendingMedicationNotification(
          i,
          'another-module',
        );
      }
      await repo.create(
        treatment(
          end: DateTime(2030, 3, 1),
          times: ['08:00', '10:00', '12:00', '14:00'],
        ),
      );
      expect(service.value.count, 52);
      expect(backend.requests.length, 60);
      expect(service.value.message, contains('Capacité limitée'));
      expect(service.value.message, contains('Rouvrez'));
    },
  );

  test(
    'unsupported target never initializes plugins or creates SQLite journal',
    () async {
      backend.supported = false;
      await service.synchronize(requestPermission: true, requestExact: true);
      expect(backend.initialized, 0);
      expect(service.value.status, MedicationNotificationStatus.unsupported);
    },
  );

  test('inexact mode is explicitly labelled approximate', () async {
    backend.exact = false;
    await repo.create(treatment());
    expect(service.value.exact, isFalse);
    expect(service.value.message, contains('approximatifs'));
  });

  testWidgets(
    'permission refusal and request action are visible in turquoise panel',
    (tester) async {
      backend.allowed = false;
      await tester.runAsync(() => service.synchronize());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MedicationNotificationPanel(service: service)),
        ),
      );
      expect(find.textContaining('non autorisées'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Autoriser les notifications'));
        await service.synchronize();
      });
      await tester.pumpAndSettle();
      expect(backend.permissionRequested, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'version 4 upgrade is additive and preserves rows and recorded history',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'sahacare_notification_migration_',
      );
      final path = '${dir.path}/medications.db';
      final legacy = MedicationRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: path,
      );
      final id = await legacy.create(treatment());
      await legacy.ensureOccurrences(
        from: DateTime(2030, 1, 7),
        through: DateTime(2030, 1, 8),
      );
      final dose = (await legacy.getOccurrencesForMedication(id)).first;
      await legacy.markOccurrenceTaken(dose.id);
      await legacy.close();
      // Build a v4 fixture from a disposable DB, never the user's database.
      final db = await databaseFactoryFfi.openDatabase(path);
      await db.execute('DROP TABLE medication_stock_movements');
      await db.execute('DROP TABLE medication_stock');
      await db.execute('DROP TABLE medication_notification_registry');
      await db.setVersion(4);
      final rowsBefore = await db.query('medications');
      final historyBefore = await db.query('medication_occurrences');
      await db.close();
      final upgraded = MedicationRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(upgraded.close);
      expect((await upgraded.getById(id))!.name, 'Médicament privé');
      expect(await upgraded.notificationRegistry(), isEmpty);
      await upgraded.close();
      final check = await databaseFactoryFfi.openDatabase(path);
      expect(await check.getVersion(), 6);
      expect(await check.query('medications'), rowsBefore);
      expect(await check.query('medication_occurrences'), historyBefore);
      await check.close();
      // The isolated fixture is retained for inspection; no data is deleted.
    },
  );
}
