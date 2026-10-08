import 'package:go_router/go_router.dart';
import '../../features/diseases/domain/entities/disease.dart';
import '../../features/diseases/presentation/screens/add_edit_disease_screen.dart';
import '../../features/diseases/presentation/screens/disease_detail_screen.dart';
import '../../features/diseases/presentation/screens/diseases_list_screen.dart';
import '../widgets/home_screen.dart';

/// Configuration principale du routeur avec GoRouter
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),

    // =========================================================================
    // Module : Gestion des Maladies (Affections médicales)
    // =========================================================================
    GoRoute(
      path: '/diseases',
      name: 'diseases-list',
      builder: (context, state) => const DiseasesListScreen(),
      routes: [
        GoRoute(
          path: 'add',
          name: 'disease-add',
          builder: (context, state) => const AddEditDiseaseScreen(),
        ),
        GoRoute(
          path: ':id',
          name: 'disease-detail',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final disease = state.extra as Disease?;
            return DiseaseDetailScreen(
              diseaseId: id,
              initialDisease: disease,
            );
          },
          routes: [
            GoRoute(
              path: 'edit',
              name: 'disease-edit',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                final disease = state.extra as Disease?;
                return AddEditDiseaseScreen(
                  diseaseId: id,
                  initialDisease: disease,
                );
              },
            ),
          ],
        ),
      ],
    ),

    // =========================================================================
    // // Ajoutez vos routes de module ici (Rendez-vous, Médicaments, etc.)
    // =========================================================================
  ],
);
