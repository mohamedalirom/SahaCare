import 'package:sahacare/features/medications/data/services/medication_access.dart';
import 'package:sahacare/features/medications/data/services/medication_notification_cleanup_store.dart';

/// Fictitious identity authority, only injected into isolated test repositories.
class TestMedicationAuthority implements MedicationSessionAuthority {
  TestMedicationAuthority({this.owner = 'demo:local', this.demo = true});
  String? owner;
  bool demo;
  int revision = 0;
  DateTime expiresAt = DateTime.utc(2099);
  Future<void> Function()? beforeVerify;
  @override
  MedicationIdentity? get initialVerifiedIdentity => owner == null
      ? null
      : MedicationIdentity(owner: owner!, demo: demo, expiresAt: expiresAt);
  @override
  String? get stamp => owner == null ? null : 'fixture:$owner:$revision';
  @override
  Future<MedicationIdentity?> verify() async {
    await beforeVerify?.call();
    return owner == null
        ? null
        : MedicationIdentity(owner: owner!, demo: demo, expiresAt: expiresAt);
  }
}

MedicationAccess testMedicationAccess() =>
    MedicationAccess(authority: TestMedicationAuthority());

class TestMedicationCleanupStore implements MedicationNotificationCleanupStore {
  Set<int> ids = {};
  @override
  Future<Set<int>> read() async => Set.of(ids);
  @override
  Future<void> write(Set<int> value) async {
    ids = Set.of(value);
  }
}
