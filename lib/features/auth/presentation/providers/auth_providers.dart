import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService.instance);

final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

/// Disponibilité matérielle de la biométrie sur l'appareil.
final biometricSupportedProvider = FutureProvider<bool>(
  (ref) => ref.read(biometricServiceProvider).isSupported(),
);

/// Libellé de la méthode (Face ID / Empreinte).
final biometricLabelProvider = FutureProvider<String>(
  (ref) => ref.read(biometricServiceProvider).methodLabel(),
);

/// Préférence « verrouillage biométrique » (persistée localement).
class BiometricEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(biometricServiceProvider).isEnabled();

  /// Active/désactive le verrou. L'activation exige une authentification réussie
  /// pour prouver que la biométrie fonctionne. Retourne l'état final.
  Future<bool> toggle(bool enable) async {
    final service = ref.read(biometricServiceProvider);
    if (enable) {
      final ok = await service.authenticate(reason: 'Confirmez pour activer le verrouillage biométrique');
      if (!ok) return state.value ?? false;
    }
    await service.setEnabled(enable);
    state = AsyncData(enable);
    return enable;
  }
}

final biometricEnabledProvider =
    AsyncNotifierProvider<BiometricEnabledNotifier, bool>(BiometricEnabledNotifier.new);
