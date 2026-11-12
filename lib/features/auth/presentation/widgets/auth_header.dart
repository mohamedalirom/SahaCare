import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Logo + titres de l'écran d'authentification (adapté clair / sombre).
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.health_and_safety_rounded, size: 44, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(subtitle, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
      ],
    );
  }
}
