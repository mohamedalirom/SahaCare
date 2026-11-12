import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sécurité au niveau de l'appareil : FaceID / Empreinte via `local_auth`.
class BiometricService {
  BiometricService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  static const _prefsKey = 'sahacare.biometric_lock_enabled';

  final LocalAuthentication _auth;

  /// Les plugins local_auth ne couvrent pas le Web / Linux.
  bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// Vrai si l'appareil sait authentifier (biométrie ou code de l'appareil).
  Future<bool> isSupported() async {
    if (!_platformSupported) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Libellé adapté au type de biométrie disponible.
  Future<String> methodLabel() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face ID / reconnaissance faciale';
      if (types.contains(BiometricType.fingerprint)) return 'Empreinte digitale';
    } catch (_) {}
    return 'Biométrie de l\'appareil';
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  /// Demande l'authentification. Retourne `false` en cas d'échec / annulation
  /// (jamais d'exception : l'UI n'a qu'un booléen à gérer).
  Future<bool> authenticate({String reason = 'Déverrouillez SahaCare pour accéder à votre dossier médical'}) async {
    if (!await isSupported()) return false;
    try {
      return await _auth.authenticate(localizedReason: reason);
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
