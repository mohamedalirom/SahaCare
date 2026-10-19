import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/app.dart';
import 'package:sahacare/core/routes/app_router.dart';

void main() {
  testWidgets('Vérification de l\'accueil et de la présence du module Médecins & Rendez-vous',
      (WidgetTester tester) async {
    appRouter.go('/');
    await tester.pumpWidget(
      const ProviderScope(
        child: SahaCareApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SahaCare'), findsOneWidget);
    expect(find.text('Médecins & Rendez-vous'), findsOneWidget);
  });
}
