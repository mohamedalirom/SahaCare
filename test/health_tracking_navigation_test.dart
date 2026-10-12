import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/app.dart';
import 'package:sahacare/core/routes/app_router.dart';

void main() {
  testWidgets('Test de navigation du module Suivi de santé (Manel)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Démarrage direct sur le module (évite de dépendre de l'écran de connexion)
    appRouter.go('/health-tracking');
    await tester.pumpWidget(const ProviderScope(child: SahaCareApp()));
    await tester.pumpAndSettle();

    // 1. Tableau de bord
    expect(find.text('Suivi de santé'), findsOneWidget);
    expect(find.text('Mes indicateurs'), findsOneWidget);

    // 2. Historique de la tension artérielle
    await tester.tap(find.text('Tension artérielle').first);
    await tester.pumpAndSettle();
    expect(find.text('Évolution (mmHg)'), findsOneWidget);

    // 3. Détail d'une mesure
    await tester.scrollUntilVisible(find.textContaining('mmHg').at(1), 200);
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Détail de la mesure'), findsOneWidget);

    // 4. Modification
    await tester.tap(find.byTooltip('Modifier la mesure'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier la mesure'), findsOneWidget);
    expect(find.text('Systolique'), findsOneWidget);

    // 5. Statistiques
    appRouter.go('/health-tracking/stats');
    await tester.pumpAndSettle();
    expect(find.text('Statistiques santé'), findsOneWidget);
  });
}
