import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Point d'entrée de l'application avec ProviderScope pour la gestion d'état Riverpod
  runApp(
    const ProviderScope(
      child: SahaCareApp(),
    ),
  );
}
