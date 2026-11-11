import 'package:shared_preferences/shared_preferences.dart';

/// Opaque OS IDs only; no owner, medicine, date or medical content. Persisted
/// before scheduling so logout/restart can cancel a request after a crash.
abstract interface class MedicationNotificationCleanupStore {
  Future<Set<int>> read();
  Future<void> write(Set<int> ids);
}

class PreferencesMedicationCleanupStore
    implements MedicationNotificationCleanupStore {
  static const key = 'sahacare.medication.cleanup_ids.v2';
  @override
  Future<Set<int>> read() async =>
      (await SharedPreferences.getInstance())
          .getStringList(key)
          ?.map(int.tryParse)
          .whereType<int>()
          .toSet() ??
      {};
  @override
  Future<void> write(Set<int> ids) async {
    if (!await (await SharedPreferences.getInstance()).setStringList(
      key,
      ids.map((id) => '$id').toList(),
    )) {
      throw StateError('Journal technique indisponible.');
    }
  }
}
