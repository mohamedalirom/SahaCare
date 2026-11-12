import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/presentation/screens/medication_form_screen.dart';

void main() {
  testWidgets('requires medication details before showing success', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MedicationFormScreen()));

    final saveButton = find.text('Enregistrer le médicament');
    await tester.scrollUntilVisible(
      saveButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Ce champ est obligatoire'), findsNWidgets(5));
    expect(find.text('Médicament ajouté avec succès'), findsNothing);
  });
}
