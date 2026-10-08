import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/app.dart';

void main() {
  testWidgets('Vérification de l\'affichage de la page d\'accueil SahaCare',
      (WidgetTester tester) async {
    // Montage de l'application avec ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: SahaCareApp(),
      ),
    );

    // Vérifie la présence du titre et du texte de bienvenue
    expect(find.text('SahaCare'), findsOneWidget);
    expect(find.text('Bienvenue sur SahaCare'), findsOneWidget);
  });
}
