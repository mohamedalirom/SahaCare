import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/data/services/medication_notification_backend.dart';
import 'package:sahacare/features/medications/data/services/medication_notification_service.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_notification_panel.dart';

void main() {
  testWidgets(
    'Chrome shows Web Push limitation without mobile API or SQLite access',
    (tester) async {
      final service = MedicationNotificationService(
        repository: MedicationRepository(),
        backend: NativeMedicationNotificationBackend(),
      );
      addTearDown(service.dispose);
      await service.synchronize(requestPermission: true, requestExact: true);
      expect(service.value.status, MedicationNotificationStatus.unsupported);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MedicationNotificationPanel(service: service)),
        ),
      );
      expect(find.textContaining('Web Push'), findsOneWidget);
      expect(find.text('Autoriser les notifications'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );
}
