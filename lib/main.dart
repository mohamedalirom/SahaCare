import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Point d'entrée avec ProviderScope pour la gestion d'état
  runApp(
    const ProviderScope(
      child: SahaCareApp(),
    ),
  );
}
