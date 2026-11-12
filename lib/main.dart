import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/supabase_config.dart';

import 'core/database/platform_db/db_init.dart';
import 'features/auth/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise la base SQLite selon la plateforme (Windows FFI, Chrome Web FFI, Mobile)
  initPlatformDatabase();

  // Supabase (initialise et attache l'écouteur auth)
  await SupabaseConfig.initialize();
  AuthService.instance.initAuthListener();
  await AuthService.instance.initBiometricState();

  // Chargement des variables d'environnement (.env pour clé Gemini)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Info: Fichier .env non chargé ou absent ($e)");
  }

  // Point d'entrée avec ProviderScope pour la gestion d'état
  runApp(
    const ProviderScope(
      child: SahaCareApp(),
    ),
  );
}
