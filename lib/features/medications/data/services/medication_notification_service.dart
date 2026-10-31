import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../medication_repository.dart';
import '../../domain/entities/medication_occurrence.dart';
import '../../domain/services/medication_reminder_planner.dart';
import 'medication_notification_backend.dart';

enum MedicationNotificationStatus {
  unsupported,
  checking,
  denied,
  scheduled,
  error,
}

class MedicationNotificationState {
  const MedicationNotificationState(
    this.status,
    this.message, {
    this.count = 0,
    this.exact = false,
  });
  final MedicationNotificationStatus status;
  final String message;
  final int count;
  final bool exact;
}

class MedicationNotificationService
    extends ValueNotifier<MedicationNotificationState>
    with WidgetsBindingObserver {
  MedicationNotificationService({
    required this.repository,
    required this.backend,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(
         const MedicationNotificationState(
           MedicationNotificationStatus.checking,
           'Vérification des notifications…',
         ),
       );

  static final instance = MedicationNotificationService(
    repository: MedicationRepository.instance,
    backend: NativeMedicationNotificationBackend(),
  );

  final MedicationRepository repository;
  final MedicationNotificationBackend backend;
  final DateTime Function() _now;
  Future<void> _tail = Future.value();
  bool _started = false;
  bool _foreground = true;
  Timer? _renewal;

  void start() {
    if (_started) return;
    _started = true;
    repository.onChanged = synchronize;
    WidgetsBinding.instance.addObserver(this);
    unawaited(synchronize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _renewal?.cancel();
    if (_foreground) unawaited(synchronize());
  }

  /// Serialized, retryable reconciliation. SQLite remains the desired state;
  /// registry + OS pending requests recover a partial operation after a crash.
  Future<void> synchronize({
    bool requestPermission = false,
    bool requestExact = false,
  }) {
    final result = _tail.then(
      (_) => _synchronize(requestPermission, requestExact),
    );
    _tail = result;
    return result;
  }

  Future<void> _synchronize(bool requestPermission, bool requestExact) async {
    if (!backend.supported) {
      value = MedicationNotificationState(
        MedicationNotificationStatus.unsupported,
        kIsWeb
            ? 'Sur Chrome, les préférences sont conservées. Les rappels persistants hors navigateur nécessitent une infrastructure Web Push, non installée.'
            : 'Les rappels système sont disponibles uniquement sur Android et iOS. Vos préférences restent enregistrées.',
      );
      return;
    }
    var count = 0;
    try {
      value = const MedicationNotificationState(
        MedicationNotificationStatus.checking,
        'Synchronisation des rappels…',
      );
      await backend.initialize();
      final permission = await backend.permissions(
        request: requestPermission,
        requestExact: requestExact,
      );
      final pending = await backend.pending();
      final ownPending = {
        for (final item in pending)
          if (item.payload?.startsWith('sahacare.medication:') == true)
            item.id: item,
      };
      final registry = await repository.notificationRegistry();
      final registered = {
        for (final row in registry) 1000000000 + (row['id'] as int): row,
      };
      if (!permission.allowed) {
        // Cancel only this module's requests, including known requests that may
        // not be returned by the OS while its permission is revoked.
        for (final id in {
          ...ownPending.keys,
          ...registered.entries
              .where((e) => e.value['signature'] != null)
              .map((e) => e.key),
        }) {
          final other = pending.where(
            (p) =>
                p.id == id &&
                p.payload?.startsWith('sahacare.medication:') != true,
          );
          if (other.isNotEmpty) {
            throw StateError('Identifiant utilisé par un autre module.');
          }
          await backend.cancel(id);
          if (registered.containsKey(id)) {
            await repository.recordNotification(id, null);
          }
        }
        value = const MedicationNotificationState(
          MedicationNotificationStatus.denied,
          'Notifications non autorisées. Activez-les dans les réglages du téléphone, puis réessayez. Vos traitements sont conservés.',
        );
        return;
      }
      final location = await backend.location();
      final medications = await repository.getAll();
      final occurrences = <MedicationOccurrence>[];
      for (final medication in medications) {
        occurrences.addAll(
          await repository.getOccurrencesForMedication(medication.id!),
        );
      }
      final otherCount = pending.length - ownPending.length;
      final capacity = backend.isIOS ? (60 - otherCount).clamp(0, 60) : 200;
      final plan = const MedicationReminderPlanner().calculate(
        medications: medications,
        occurrences: occurrences,
        location: location,
        now: _now(),
        limit: capacity,
      );
      final desired = <int, MedicationReminder>{};
      for (final reminder in plan.reminders) {
        final id = await repository.notificationId(reminder.key);
        if (pending.any(
          (p) =>
              p.id == id &&
              p.payload?.startsWith('sahacare.medication:') != true,
        )) {
          throw StateError('Identifiant utilisé par un autre module.');
        }
        desired[id] = reminder;
      }
      // Cancel obsolete dates first; never use cancelAll (other modules).
      for (final id in {
        ...ownPending.keys,
        ...registered.entries
            .where((e) => e.value['signature'] != null)
            .map((e) => e.key),
      }) {
        if (!desired.containsKey(id)) {
          if (pending.any(
            (p) =>
                p.id == id &&
                p.payload?.startsWith('sahacare.medication:') != true,
          )) {
            throw StateError('Identifiant utilisé par un autre module.');
          }
          await backend.cancel(id);
          if (registered.containsKey(id)) {
            await repository.recordNotification(id, null);
          }
        }
      }
      for (final entry in desired.entries) {
        final modeSignature = '${entry.value.signature}|${permission.exact}';
        // An OS request without an acknowledged journal row is replayed safely
        // with the same ID (replace, not duplicate).
        if (ownPending[entry.key]?.payload != entry.value.payload ||
            registered[entry.key]?['signature'] != modeSignature) {
          // Clear a stale request first, so a failed replacement cannot leave
          // the old reminder firing at an incorrect time.
          if (ownPending.containsKey(entry.key)) {
            await backend.cancel(entry.key);
          }
          await repository.recordNotification(entry.key, null);
          await backend.schedule(
            entry.key,
            entry.value,
            exact: permission.exact,
          );
          await repository.recordNotification(entry.key, modeSignature);
        }
        count++;
      }
      final until = plan.reminders.isEmpty
          ? ''
          : ' Prochaine réserve jusqu’au ${plan.reminders.last.at.day}/${plan.reminders.last.at.month} à ${plan.reminders.last.at.hour.toString().padLeft(2, '0')}:${plan.reminders.last.at.minute.toString().padLeft(2, '0')} (${location.name}).';
      value = MedicationNotificationState(
        MedicationNotificationStatus.scheduled,
        'Notifications autorisées. $count rappel(s) programmé(s), sans confirmation de réception.'
        '$until Rouvrez régulièrement Médicaments pour renouveler la réserve.'
        '${plan.truncated ? ' Capacité limitée : seules les prochaines prises sont programmées.' : ''}'
        '${!permission.exact ? ' Horaires approximatifs : accès aux alarmes exactes non accordé.' : ''}',
        count: count,
        exact: permission.exact,
      );
    } catch (_) {
      // Do not leak medical data or native exception payloads into the UI.
      value = MedicationNotificationState(
        MedicationNotificationStatus.error,
        'Synchronisation incomplète : $count rappel(s) vérifié(s). Certains rappels n’ont pas pu être programmés ou annulés. Vos modifications sont enregistrées ; réessayez.',
        count: count,
      );
    } finally {
      if (_started && _foreground) {
        _renewal?.cancel();
        _renewal = Timer(const Duration(minutes: 15), () {
          unawaited(synchronize());
        });
      }
    }
  }

  @override
  void dispose() {
    _renewal?.cancel();
    if (_started) {
      repository.onChanged = null;
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
