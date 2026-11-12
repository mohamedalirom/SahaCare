import 'package:flutter/material.dart';

import '../../../../i18n/strings.g.dart';
import '../../domain/entities/user_profile.dart';

/// Carte « Complétion du profil » : CircularProgressIndicator animé + conseils.
class ProfileCompletionCard extends StatelessWidget {
  const ProfileCompletionCard({super.key, required this.profile, this.onComplete});

  final UserProfile profile;

  /// Ouvre le formulaire d'édition du profil.
  final VoidCallback? onComplete;

  static Color colorFor(double completion) {
    if (completion < 0.4) return const Color(0xFFEF4444);
    if (completion < 0.8) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String _localizeCompletionItem(String label) {
    switch (label) {
      case 'Nom complet':
        return t.fullName;
      case 'Date de naissance':
        return t.birthDate;
      case 'Sexe biologique':
        return t.biologicalSex;
      case 'Groupe sanguin':
        return t.bloodGroup;
      case 'Taille':
        return t.height;
      case 'Poids':
        return t.weight;
      case 'Statut tabagique':
        return t.tobacco;
      case "Consommation d'alcool":
        return t.alcohol;
      case 'Activité physique':
        return t.physicalActivity;
      default:
        return label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completion = profile.completion;
    final color = colorFor(completion);
    final missing = profile.completionItems.where((i) => !i.isDone).map((i) => i.label).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: completion),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 9,
                      color: color.withValues(alpha: 0.15),
                    ),
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor: Colors.transparent,
                    ),
                    Center(
                      child: Text(
                        '${(value * 100).round()}%',
                        style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20, color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    completion >= 1 ? t.profileComplete : t.profileCompletion,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    missing.isEmpty
                        ? t.allInfoProvided
                        : '${t.toComplete}${missing.take(3).map(_localizeCompletionItem).join(', ')}${missing.length > 3 ? '…' : ''}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (missing.isNotEmpty && onComplete != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextButton(
                        onPressed: onComplete,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(t.completeMyProfile),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
