import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/services/medication_reminder_planner.dart';

class MedicationNotificationPermission {
  const MedicationNotificationPermission({
    required this.allowed,
    required this.exact,
  });
  final bool allowed;
  final bool exact;
}

class PendingMedicationNotification {
  const PendingMedicationNotification(this.id, this.payload);
  final int id;
  final String? payload;
}

abstract interface class MedicationNotificationBackend {
  bool get supported;
  bool get isIOS;
  Future<void> initialize();
  Future<tz.Location> location();
  Future<MedicationNotificationPermission> permissions({
    bool request = false,
    bool requestExact = false,
  });
  Future<List<PendingMedicationNotification>> pending();
  Future<void> schedule(
    int id,
    MedicationReminder reminder, {
    required bool exact,
  });
  Future<void> cancel(int id);
}

/// Mobile-only adapter. No plugin call is made on Web or desktop.
class NativeMedicationNotificationBackend
    implements MedicationNotificationBackend {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || isIOS);
  @override
  bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> initialize() async {
    if (!supported || _initialized) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_medication_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<tz.Location> location() async {
    final info = await FlutterTimezone.getLocalTimezone();
    return tz.getLocation(info.identifier);
  }

  @override
  Future<MedicationNotificationPermission> permissions({
    bool request = false,
    bool requestExact = false,
  }) async {
    if (!supported) {
      return const MedicationNotificationPermission(
        allowed: false,
        exact: false,
      );
    }
    await initialize();
    if (isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()!;
      if (request) {
        await ios.requestPermissions(alert: true, sound: true, badge: false);
      }
      final settings = await ios.checkPermissions();
      return MedicationNotificationPermission(
        allowed: settings?.isAlertEnabled == true,
        exact: true,
      );
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
    if (request) await android.requestNotificationsPermission();
    if (requestExact) await android.requestExactAlarmsPermission();
    return MedicationNotificationPermission(
      allowed: await android.areNotificationsEnabled() == true,
      exact: await android.canScheduleExactNotifications() == true,
    );
  }

  @override
  Future<List<PendingMedicationNotification>> pending() async =>
      (await _plugin.pendingNotificationRequests())
          .map((item) => PendingMedicationNotification(item.id, item.payload))
          .toList();

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> schedule(
    int id,
    MedicationReminder reminder, {
    required bool exact,
  }) => _plugin.zonedSchedule(
    id: id,
    title: 'Rappel SahaCare',
    body: 'Une prise de médicament est prévue. Consultez vos traitements.',
    scheduledDate: reminder.at,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'sahacare_medications_v1',
        'Rappels de médicaments',
        channelDescription: 'Horaires des traitements SahaCare',
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.private,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    ),
    androidScheduleMode: exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
    payload: reminder.payload,
  );
}
