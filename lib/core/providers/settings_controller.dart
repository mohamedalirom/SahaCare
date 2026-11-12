import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import '../../i18n/strings.g.dart';

import '../../features/profil/presentation/providers/profile_providers.dart';
import '../../features/profil/domain/repositories/medical_repository.dart';
import '../../features/auth/services/auth_service.dart';
import '../database/database_helper.dart';

class SettingsState {
  final ThemeMode themeMode;
  final Locale locale;
  final bool isMetric;
  final bool profileVisibleToDoctors;
  final bool biometricEnabled;
  final bool isBiometricSupported;
  final bool isLoading;

  SettingsState({
    required this.themeMode,
    required this.locale,
    required this.isMetric,
    required this.profileVisibleToDoctors,
    required this.biometricEnabled,
    this.isBiometricSupported = true,
    required this.isLoading,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? isMetric,
    bool? profileVisibleToDoctors,
    bool? biometricEnabled,
    bool? isBiometricSupported,
    bool? isLoading,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      isMetric: isMetric ?? this.isMetric,
      profileVisibleToDoctors: profileVisibleToDoctors ?? this.profileVisibleToDoctors,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      isBiometricSupported: isBiometricSupported ?? this.isBiometricSupported,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final settingsControllerProvider = NotifierProvider.autoDispose<SettingsController, SettingsState>(SettingsController.new);

class SettingsController extends Notifier<SettingsState> {
  static const String biometricPrefsKey = 'sahacare.biometric_lock_enabled';
  final LocalAuthentication _localAuth = LocalAuthentication();
  MedicalRepository get _medicalRepository => ref.read(medicalRepositoryProvider);

  /// Set when this notifier instance is disposed (e.g. invalidated on logout)
  /// so a late async load can never write into a dead/new session's state.
  bool _disposed = false;

  /// Clears user-scoped session data while strictly preserving device-wide app
  /// preferences ('themeMode', 'locale', 'isMetric', and biometric settings),
  /// and safely closes the SQLite connection to avoid locked-database bugs on next login.
  static Future<void> clearLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Snapshot device-wide preferences into temporary variables
      final int? savedThemeMode = prefs.getInt('themeMode');
      final String? savedLocale = prefs.getString('locale');
      final bool? savedIsMetric = prefs.getBool('isMetric');
      final bool? savedBiometric = prefs.getBool(biometricPrefsKey) ?? prefs.getBool('biometric_enabled');

      // 2. Clear all cached user session data
      await prefs.clear();

      // 3. Immediately restore preserved device-wide preferences
      if (savedThemeMode != null) {
        await prefs.setInt('themeMode', savedThemeMode);
      }
      if (savedLocale != null) {
        await prefs.setString('locale', savedLocale);
      }
      if (savedIsMetric != null) {
        await prefs.setBool('isMetric', savedIsMetric);
      }
      if (savedBiometric != null) {
        await prefs.setBool(biometricPrefsKey, savedBiometric);
        await prefs.setBool('biometric_enabled', savedBiometric);
      }
    } catch (e) {
      debugPrint('Error clearing local SharedPreferences session: $e');
    }

    // 4. Safely close sqflite connection (reopened lazily by next session)
    try {
      await DatabaseHelper.instance.close();
    } catch (e) {
      debugPrint('Error closing local SQLite database: $e');
    }
  }

  @override
  SettingsState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    Future.microtask(_loadSettings);
    // Always a fresh state: never loading until an action starts.
    return SettingsState(
      themeMode: ThemeMode.system,
      locale: const Locale('fr'),
      isMetric: true,
      profileVisibleToDoctors: true,
      biometricEnabled: false,
      isBiometricSupported: true,
      isLoading: false,
    );
  }

  // --- 1. Load Local Preferences ---
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = (prefs.getInt('themeMode') ?? ThemeMode.system.index).clamp(0, ThemeMode.values.length - 1);
      final localeStr = prefs.getString('locale') ?? 'fr';
      final isMetric = prefs.getBool('isMetric') ?? true;
      final biometricEnabled = prefs.getBool(biometricPrefsKey) ?? prefs.getBool('biometric_enabled') ?? false;

      bool isBiometricSupported = false;
      try {
        isBiometricSupported = await _localAuth.isDeviceSupported() || await _localAuth.canCheckBiometrics;
      } catch (_) {
        isBiometricSupported = false;
      }

      if (_disposed) return;
      
      Intl.defaultLocale = localeStr; // Update intl immediately on load
      LocaleSettings.setLocaleRaw(localeStr);

      state = state.copyWith(
        themeMode: ThemeMode.values[themeIndex],
        locale: Locale(localeStr),
        isMetric: isMetric,
        biometricEnabled: biometricEnabled,
        isBiometricSupported: isBiometricSupported,
        isLoading: false,
      );

      // Local visibility flag from SQLite
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          final isVisible = await _medicalRepository.getProfileVisibility(user.id);
          if (!_disposed) {
            state = state.copyWith(
              profileVisibleToDoctors: isVisible,
            );
          }
        } catch (e) {
          debugPrint('Silent warning: Failed to fetch profile visibility flag from local SQLite: $e');
        }
      }
    } catch (_) {
      if (!_disposed) state = state.copyWith(isLoading: false);
    }
  }

  // --- 2. Global State Methods (Theme, Language, Units) ---
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('themeMode', mode.index));
  }

  void setLocale(Locale locale) {
    Intl.defaultLocale = locale.languageCode;
    LocaleSettings.setLocaleRaw(locale.languageCode);
    state = state.copyWith(locale: locale);
    SharedPreferences.getInstance().then((prefs) => prefs.setString('locale', locale.languageCode));
  }

  void setLocaleRaw(String rawLocale) {
    setLocale(Locale(rawLocale));
  }

  void setMetric(bool isMetric) {
    state = state.copyWith(isMetric: isMetric);
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('isMetric', isMetric));
  }

  /// Helper functions for UI conversion (kg/cm to lbs/in) without altering DB source of truth
  static double kgToLbs(double kg) => kg * 2.20462;
  static double cmToInches(double cm) => cm * 0.393701;

  // --- 3. Biometric Authentication (Hardware & SharedPreferences) ---
  Future<void> toggleBiometrics(bool enable, BuildContext context) async {
    final l10n = context.t;
    if (enable) {
      bool isSupported = false;
      try {
        isSupported = await _localAuth.isDeviceSupported() || await _localAuth.canCheckBiometrics;
      } catch (_) {
        isSupported = false;
      }

      if (!isSupported) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.biometricsNotSupported),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      bool authenticated = false;
      try {
        authenticated = await _localAuth.authenticate(
          localizedReason: l10n.biometricsPromptReason,
        );
      } catch (e) {
        debugPrint('Biometric authentication error: $e');
        authenticated = false;
      }

      if (!authenticated) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.biometricsAuthFailed),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(biometricPrefsKey, true);
      await prefs.setBool('biometric_enabled', true);

      if (!_disposed) {
        state = state.copyWith(biometricEnabled: true);
      }
      AuthService.instance.setBiometricEnabled(true);
      AuthService.instance.setBiometricUnlocked(true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.biometricsEnabled),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(biometricPrefsKey, false);
      await prefs.setBool('biometric_enabled', false);

      if (!_disposed) {
        state = state.copyWith(biometricEnabled: false);
      }
      AuthService.instance.setBiometricEnabled(false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.biometricsDisabled),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- 4. Account & Security (Supabase Auth) ---
  Future<void> resetPassword(BuildContext context) async {
    final l10n = context.t;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.email == null || user.email!.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.passwordResetNoEmail),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    
    state = state.copyWith(isLoading: true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(user.email!.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.passwordResetSent),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        final isRateLimit = e.statusCode == '429' ||
            e.code == 'over_email_send_rate_limit' ||
            e.message.toLowerCase().contains('over_email_send_rate_limit') ||
            e.message.toLowerCase().contains('rate limit') ||
            e.message.toLowerCase().contains('too many');

        final String message = isRateLimit
            ? 'Vous avez demandé trop de liens. Veuillez patienter un moment avant de réessayer.'
            : 'Impossible d\'envoyer le lien de réinitialisation. Veuillez réessayer plus tard.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isRateLimit ? Colors.orange : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Une erreur est survenue lors de l\'envoi du lien. Veuillez réessayer plus tard.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (!_disposed) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> logout(BuildContext context) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    // Pop the bottom sheet if mounted to cleanly dismiss modal route
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }

    state = state.copyWith(isLoading: true);
    try {
      await AuthService.instance.signOut();
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Erreur lors de la déconnexion: ${e.toString()}')),
      );
    } finally {
      // Guaranteed reset of loading state
      if (!_disposed) {
        state = state.copyWith(isLoading: false);
      }

      // Purge local session cache and safely close SQLite
      await clearLocalSession();

      // Invalidate session providers
      ref.invalidate(profileProvider);
      ref.invalidate(medicalHistoryProvider);
      ref.invalidate(settingsControllerProvider);

      // Navigate back to login
      if (context.mounted) {
        router.go('/login');
      }
    }
  }

  Future<void> deleteAccount(BuildContext context, String password) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (context.mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }

    state = state.copyWith(isLoading: true);
    try {
      await Supabase.instance.client.rpc('delete_user_account', params: {'password_confirm': password});
      await AuthService.instance.signOut();
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression du compte: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (!_disposed) {
        state = state.copyWith(isLoading: false);
      }

      await clearLocalSession();

      ref.invalidate(profileProvider);
      ref.invalidate(medicalHistoryProvider);
      ref.invalidate(settingsControllerProvider);

      if (context.mounted) {
        router.go('/login');
      }
    }
  }

  // --- 5. Privacy & Data (Profile Visibility - Offline-First) ---
  Future<void> toggleProfileVisibility(bool isVisible, BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session non active. Connectez-vous pour modifier la visibilité.')),
        );
      }
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _medicalRepository.updateProfileVisibility(user.id, isVisible);
          
      if (!_disposed) {
        state = state.copyWith(profileVisibleToDoctors: isVisible);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visibilité du profil mise à jour.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de mise à jour: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (!_disposed) {
        state = state.copyWith(isLoading: false);
      }
    }
  }
}
