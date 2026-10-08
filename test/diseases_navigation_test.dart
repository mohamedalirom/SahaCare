import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/app.dart';

void main() {
  testWidgets('Test du flux de navigation du module Gestion des Maladies',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SahaCareApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Sur l'accueil, on tape sur le module "Gestion des Maladies & Affections"
    final moduleCard = find.text('Gestion des Maladies & Affections');
    expect(moduleCard, findsOneWidget);
    await tester.tap(moduleCard);
    await tester.pumpAndSettle();

    // 2. On arrive sur la liste des affections
    expect(find.text('Mes Affections & Maladies'), findsOneWidget);
    expect(find.text('Diabète de Type 2'), findsOneWidget);

    // 3. On tape sur une affection pour voir son détail
    await tester.tap(find.text('Diabète de Type 2'));
    await tester.pumpAndSettle();
    expect(find.text('Détail de l\'Affection'), findsOneWidget);
    expect(find.text('Description & Diagnostic'), findsOneWidget);

    // 4. On clique sur le bouton de modification
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Modifier l\'Affection'), findsOneWidget);
  });
}
