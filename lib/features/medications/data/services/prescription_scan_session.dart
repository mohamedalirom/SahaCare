import 'medication_access.dart';

/// Medication rows are not account-scoped yet: no import into a real account.
class PrescriptionScanSession {
  const PrescriptionScanSession({
    required this.key,
    required this.localDemo,
    this.verified = false,
  });
  final String key;
  final bool localDemo;
  final bool verified;
  bool get canImport => verified || (localDemo && key == 'local-demo-user');
  static PrescriptionScanSession current() {
    try {
      final lease = MedicationAccess.instance.capture();
      return PrescriptionScanSession(
        key: '${lease.owner}@${lease.generation}',
        localDemo: lease.demo,
        verified: true,
      );
    } on MedicationAccessDenied {
      return const PrescriptionScanSession(key: '', localDemo: false);
    }
  }
}
