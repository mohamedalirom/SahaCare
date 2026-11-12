import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/core/widgets/phone_frame_wrapper.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/presentation/screens/medication_form_screen.dart';

import 'helpers/medication_test_access.dart';

class _NoStorageRepository extends MedicationRepository {
  _NoStorageRepository() : super(access: testMedicationAccess());
  int writes = 0;
  @override
  Future<List<Medication>> getAll() async => [];
  @override
  Future<int> create(Medication medication) async => ++writes;
}

void main() {
  testWidgets('focused dosage survives viewport and keyboard metric changes', (
    tester,
  ) async {
    final repository = _NoStorageRepository();
    addTearDown(repository.access.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 860);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => PhoneFrameWrapper(child: child!),
        home: MedicationFormScreen(repository: repository),
      ),
    );
    final dosage = find.byType(TextFormField).at(1);
    await tester.enterText(dosage, 'DOSAGE FICTIF NON ENREGISTRE');
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(440, 956),
      Size(956, 440),
      Size(800, 1000),
    ]) {
      tester.view.physicalSize = size;
      for (final keyboardHeight in [180.0, 0.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size / $keyboardHeight');
        expect(find.text('DOSAGE FICTIF NON ENREGISTRE'), findsOneWidget);
      }
    }
    expect(repository.writes, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
