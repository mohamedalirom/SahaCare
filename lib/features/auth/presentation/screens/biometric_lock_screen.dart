import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../profil/presentation/providers/profile_providers.dart';
import '../providers/auth_providers.dart';

/// Écran de verrouillage FaceID / Empreinte affiché quand une session existe
/// déjà au lancement et que le verrou biométrique est activé.
class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await ref.read(biometricServiceProvider).authenticate();
    if (!mounted) return;
    if (ok) {
      ref.read(authServiceProvider).setBiometricUnlocked(true);
      context.go('/profil');
    } else {
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  Future<void> _switchAccount() async {
    await ref.read(authServiceProvider).signOut();
    ref.invalidate(profileProvider);
    ref.invalidate(medicalHistoryProvider);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = ref.watch(biometricLabelProvider).value ?? 'Biométrie';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Container(
                    width: 120 + 12 * _pulse.value,
                    height: 120 + 12 * _pulse.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor.withValues(alpha: 0.10 + 0.08 * _pulse.value),
                    ),
                    child: child,
                  ),
                  child: Icon(
                    _failed ? Icons.lock_outline : Icons.fingerprint,
                    size: 64,
                    color: _failed ? theme.colorScheme.error : AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text('SahaCare verrouillé', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                _failed
                    ? 'Authentification échouée. Réessayez.'
                    : 'Utilisez $label pour accéder à votre dossier médical.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _busy ? null : _unlock,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Déverrouiller'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _switchAccount,
                child: const Text('Se connecter avec un autre compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
