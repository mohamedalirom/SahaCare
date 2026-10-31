import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/data/services/medication_notification_backend.dart';
import 'package:sahacare/features/medications/domain/services/medication_reminder_planner.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezoneChannel = MethodChannel('flutter_timezone');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    data.initializeTimeZones();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'pendingNotificationRequests') return [];
          return true;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          timezoneChannel,
          (_) async => {'identifier': 'Europe/Paris'},
        );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, null);
  });

  test('Android adapter sends a one-shot zoned request and cancellation to native channel', () async {
    final backend = NativeMedicationNotificationBackend();
    await backend.initialize();
    final permission = await backend.permissions();
    expect(permission.allowed, isTrue);
    expect(permission.exact, isTrue);
    final location = await backend.location();
    final reminder = MedicationReminder(
      key: '1/2030-1-7/09:00',
      at: tz.TZDateTime(location, 2030, 1, 7, 9),
    );
    await backend.schedule(1000000001, reminder, exact: true);
    final arguments =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments as Map;
    expect(arguments['id'], 1000000001);
    expect(arguments['timeZoneName'], 'Europe/Paris');
    expect(arguments['payload'], reminder.payload);
    expect(arguments['matchDateTimeComponents'], isNull);
    expect(arguments['title'], 'Rappel SahaCare');
    expect(
      calls.any((c) => c.method == 'requestNotificationsPermission'),
      isFalse,
    );
    await backend.cancel(1000000001);
    expect((calls.last.arguments as Map)['id'], 1000000001);
    expect(calls.last.method, 'cancel');
  });

  test('permission prompts occur only on explicit request', () async {
    final backend = NativeMedicationNotificationBackend();
    await backend.permissions(request: true, requestExact: true);
    expect(
      calls.any((c) => c.method == 'requestNotificationsPermission'),
      isTrue,
    );
    expect(
      calls.any((c) => c.method == 'requestExactAlarmsPermission'),
      isTrue,
    );
  });

  test('desktop adapter initialization and permission check never call mobile APIs', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final backend = NativeMedicationNotificationBackend();
    expect(backend.supported, isFalse);
    await backend.initialize();
    expect((await backend.permissions(request: true)).allowed, isFalse);
    expect(calls, isEmpty);
  });
}
