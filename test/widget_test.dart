import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/app.dart';

void main() {
  testWidgets('Vérification de l\'affichage de l\'accueil et du module Maladies',
      (WidgetTester tester) async {
    // Montage de l'application avec ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: SahaCareApp(),
      ),
    );

    // Vérifie la présence du titre et du module Maladies
    expect(find.text('SahaCare'), findsOneWidget);
    expect(find.text('Gestion des Maladies & Affections'), findsOneWidget);
  });
}
