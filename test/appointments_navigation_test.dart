import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/app.dart';

void main() {
  testWidgets('Test complet de navigation du module Médecins et Rendez-vous (dali)',
      (WidgetTester tester) async {
    // Montage de l'application
    await tester.pumpWidget(
      const ProviderScope(
        child: SahaCareApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Clic sur le module depuis l'accueil
    final moduleCard = find.text('Médecins & Rendez-vous');
    expect(moduleCard, findsOneWidget);
    await tester.tap(moduleCard);
    await tester.pumpAndSettle();

    // 2. Vérification de l'arrivée sur le Dashboard Rendez-vous & Médecins
    expect(find.text('Médecins & Rendez-vous'), findsOneWidget);
    expect(find.text('Dr. Karim Mansour'), findsWidgets);

    // 3. Clic sur un rendez-vous pour voir son détail
    await tester.tap(find.text('Dr. Karim Mansour').first);
    await tester.pumpAndSettle();
    expect(find.text('Détail du Rendez-vous'), findsOneWidget);
    expect(find.text('Motif de Consultation'), findsOneWidget);
    expect(find.text('Rappel programmé'), findsOneWidget);

    // 4. Clic sur le bouton de modification dans l'AppBar via son tooltip
    final editButton = find.byTooltip('Modifier le rendez-vous');
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(find.text('Modifier le Rendez-vous'), findsOneWidget);
  });
}
