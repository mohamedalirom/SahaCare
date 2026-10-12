import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import 'logout_dialog.dart';

/// Section « Paramètres & sécurité » : verrou biométrique + déconnexion.
class SecuritySettingsCard extends ConsumerWidget {
  const SecuritySettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final supported = ref.watch(biometricSupportedProvider).value ?? false;
    final enabled = ref.watch(biometricEnabledProvider).value ?? false;
    final methodLabel = ref.watch(biometricLabelProvider).value ?? 'Biométrie';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: SwitchListTile.adaptive(
            secondary: Icon(Icons.fingerprint, color: theme.colorScheme.primary, size: 28),
            title: const Text('Verrouillage biométrique'),
            subtitle: Text(
              supported ? 'Protégez l\'accès avec $methodLabel' : 'Non disponible sur cet appareil',
              style: theme.textTheme.bodyMedium,
            ),
            value: supported && enabled,
            onChanged: supported
                ? (value) async {
                    final result = await ref.read(biometricEnabledProvider.notifier).toggle(value);
                    if (value && !result && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Authentification annulée : verrou non activé.')),
                      );
                    }
                  }
                : null,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const Key('logout_button'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            onPressed: () => confirmAndLogout(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Se déconnecter'),
          ),
        ),
      ],
    );
  }
}
