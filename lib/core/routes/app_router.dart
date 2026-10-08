import 'package:go_router/go_router.dart';
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
    // // Ajoutez vos routes de module ici
    // Exemple :
    // GoRoute(
    //   path: '/votre-module',
    //   name: 'votre-module',
    //   builder: (context, state) => const VotreScreen(),
    // ),
    // =========================================================================
  ],
);
