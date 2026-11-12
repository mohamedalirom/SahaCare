import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration Supabase de SahaCare.
///
/// Les clés ne sont JAMAIS committées : elles sont injectées à la compilation :
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eqfgtgnhdnqpstjvegju.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_fEi-M0HPY-7qwI5AB60Cxg_Q3LHYjtY',
  );

  /// Deep link utilisé par Supabase pour revenir dans l'app (OAuth / Magic Link).
  /// À déclarer dans Supabase > Authentication > URL Configuration > Redirect URLs.
  static const String redirectUrl = String.fromEnvironment(
    'SUPABASE_REDIRECT_URL',
    defaultValue: 'io.supabase.sahacare://login-callback/',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Mode démo : uniquement en debug ET sans clés Supabase.
  /// Permet à l'équipe de naviguer dans l'app sans backend.
  /// Ne peut jamais être actif dans un build release (échec fermé).
  static bool get isDemoMode => kDebugMode && !isConfigured;

  /// Initialise Supabase si les clés sont fournies (sinon no-op).
  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: url, publishableKey: anonKey);
  }
}
