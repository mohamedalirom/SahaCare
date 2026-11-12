import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Couleurs neutres du module adaptées au thème clair / sombre
extension HealthPalette on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  /// Texte principal (titres, valeurs)
  Color get healthText => _isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimaryColor;

  /// Texte secondaire (sous-titres, libellés)
  Color get healthTextSecondary => _isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondaryColor;

  /// Bordures des cartes et champs
  Color get healthBorder => _isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

  /// Fond des cartes, champs et feuilles
  Color get healthSurface => _isDark ? AppTheme.darkSurface : AppTheme.surfaceColor;
}
