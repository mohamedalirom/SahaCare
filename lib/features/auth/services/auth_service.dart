import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../profil/services/profile_service.dart';

/// Erreur d'authentification présentable à l'utilisateur (message déjà localisé).
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Utilisateur de la session courante (indépendant du SDK Supabase).
@immutable
class SessionUser {
  const SessionUser({required this.id, required this.email, this.fullName});

  final String id;
  final String email;
  final String? fullName;
}

/// Service d'authentification Supabase.
///
/// - Email / mot de passe, Google & Apple (OAuth), Magic Link (OTP e-mail)
/// - Déconnexion qui purge la session et les caches locaux
/// - [ChangeNotifier] : le routeur s'y abonne (`refreshListenable`) pour
///   rediriger automatiquement vers /login dès que la session disparaît.
///
/// En mode démo (debug + sans clés Supabase), seule la connexion
/// email / mot de passe est simulée en mémoire.
class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  bool _isBiometricEnabled = false;
  bool get isBiometricEnabled => _isBiometricEnabled;

  bool _isBiometricUnlocked = false;
  bool get isBiometricUnlocked => _isBiometricUnlocked;

  Future<void> initBiometricState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isBiometricEnabled = prefs.getBool('sahacare.biometric_lock_enabled') ??
          prefs.getBool('biometric_enabled') ??
          false;
    } catch (e) {
      _isBiometricEnabled = false;
    }
    notifyListeners();
  }

  void setBiometricEnabled(bool enabled) {
    _isBiometricEnabled = enabled;
    notifyListeners();
  }

  void setBiometricUnlocked(bool unlocked) {
    _isBiometricUnlocked = unlocked;
    notifyListeners();
  }

  // Initialise l'écouteur d'événements auth une fois Supabase initialisé.
  void initAuthListener() {
    if (_subscription == null && SupabaseConfig.isConfigured) {
      try {
        _subscription = _client.auth.onAuthStateChange.listen((_) => notifyListeners());
      } catch (e) {
        debugPrint('Erreur auth subscription: $e');
      }
    }
  }

  // Conservé pour la durée de vie de l'application (singleton).
  StreamSubscription<AuthState>? _subscription;
  SessionUser? _demoUser;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool get _live => SupabaseConfig.isConfigured;
  SupabaseClient get _client => Supabase.instance.client;

  SessionUser? get currentUser {
    if (_live) {
      try {
        final user = _client.auth.currentUser;
        if (user == null) return null;
        final name = user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
        return SessionUser(
          id: user.id,
          email: user.email ?? '',
          fullName: name is String ? name : null,
        );
      } catch (_) {
        return null;
      }
    }
    return SupabaseConfig.isDemoMode ? _demoUser : null;
  }

  bool get isAuthenticated => currentUser != null;

  void _ensureBackend() {
    if (!_live && !SupabaseConfig.isDemoMode) {
      throw const AuthFailure(
        'Supabase n\'est pas configurÃ©. Fournissez SUPABASE_URL et SUPABASE_ANON_KEY.',
      );
    }
  }

  void _ensureLive(String feature) {
    if (!_live) {
      throw AuthFailure(
        'Mode dÃ©mo : configurez Supabase (--dart-define) pour utiliser $feature.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Email / mot de passe
  // ---------------------------------------------------------------------------
  Future<void> signInWithPassword({required String email, required String password}) async {
    _ensureBackend();
    if (!_live) {
      _demoUser = SessionUser(id: 'demo-user', email: email.trim(), fullName: 'Utilisateur démo');
      _isBiometricUnlocked = true;
      notifyListeners();
      return;
    }
    await _guard(() => _client.auth.signInWithPassword(email: email.trim(), password: password));
    _isBiometricUnlocked = true;
    notifyListeners();
  }

  /// Crée un compte. Retourne `true` si une session est ouverte immédiatement,
  /// `false` si une confirmation par e-mail est requise.
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _ensureBackend();
    if (!_live) {
      _demoUser = SessionUser(id: 'demo-user', email: email.trim(), fullName: fullName.trim());
      _isBiometricUnlocked = true;
      notifyListeners();
      return true;
    }
    final response = await _guard(
      () => _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
        emailRedirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
      ),
    );
    if (response.session != null) {
      _isBiometricUnlocked = true;
    }
    return response.session != null;
  }

  // ---------------------------------------------------------------------------
  // Magic Link (OTP e-mail sans mot de passe)
  // ---------------------------------------------------------------------------
  Future<void> signInWithOtp({required String email}) async {
    _ensureBackend();
    _ensureLive('les Magic Links');
    await _guard(
      () => _client.auth.signInWithOtp(
        email: email.trim(),
        emailRedirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
      ),
    );
  }

  /// Alias de [signInWithOtp]
  Future<void> sendMagicLink(String email) => signInWithOtp(email: email);

  // ---------------------------------------------------------------------------
  // OAuth (Google / Apple)
  // ---------------------------------------------------------------------------
  Future<void> signInWithOAuth(OAuthProvider provider) async {
    _ensureBackend();
    _ensureLive('la connexion ${provider.name}');
    await _guard(
      () => _client.auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
      ),
    );
  }

  /// Alias de [signInWithOAuth]
  Future<void> signInWithProvider(OAuthProvider provider) => signInWithOAuth(provider);

  Future<void> signInWithGoogle() => signInWithOAuth(OAuthProvider.google);
  Future<void> signInWithApple() => signInWithOAuth(OAuthProvider.apple);

  // ---------------------------------------------------------------------------
  // DÃ©connexion
  // ---------------------------------------------------------------------------
  /// Ferme la session Supabase et purge les donnÃ©es locales de l'utilisateur.
  Future<void> signOut() async {
    try {
      if (_live) {
        await _client.auth.signOut();
      }
    } on AuthException catch (e) {
      throw AuthFailure(_translate(e));
    } finally {
      // Toujours purger l'état local, même si l'appel réseau échoue.
      _demoUser = null;
      _isBiometricUnlocked = false;
      ProfileService.clearLocalCache();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      debugPrint('Supabase AuthException: ${e.message}');
      throw AuthFailure(_translate(e));
    } catch (e, stack) {
      debugPrint('Supabase Auth unexpected error: $e\n$stack');
      throw AuthFailure('Une erreur est survenue: $e');
    }
  }

  String _translate(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) return 'Email ou mot de passe incorrect.';
    if (msg.contains('email not confirmed')) return 'Veuillez confirmer votre e-mail avant de vous connecter.';
    if (msg.contains('already registered') || msg.contains('already been registered')) {
      return 'Un compte existe dÃ©jÃ  avec cet e-mail.';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Trop de tentatives. RÃ©essayez dans quelques instants.';
    }
    if (msg.contains('password')) return 'Mot de passe invalide (6 caractÃ¨res minimum).';
    return e.message;
  }
}
