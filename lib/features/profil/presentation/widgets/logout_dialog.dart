import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/settings_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/services/auth_service.dart';
import '../providers/profile_providers.dart';

/// Demande confirmation puis ferme la session et redirige vers /login.
Future<void> confirmAndLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Icon(Icons.logout_rounded, size: 32, color: Theme.of(dialogContext).colorScheme.error),
      title: const Text('Se déconnecter ?'),
      content: const Text(
        'Votre session sera fermée sur cet appareil. '
        'Vous devrez vous reconnecter pour accéder à votre dossier médical.',
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Se déconnecter'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await ref.read(authServiceProvider).signOut();
  } on AuthFailure catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // Purge des données utilisateur (mémoire + cache local), même si l'appel réseau a échoué.
  await SettingsController.clearLocalSession();

  if (context.mounted) context.go('/login');
  
  ref.invalidate(profileProvider);
  ref.invalidate(medicalHistoryProvider);
  ref.invalidate(settingsControllerProvider);
}
