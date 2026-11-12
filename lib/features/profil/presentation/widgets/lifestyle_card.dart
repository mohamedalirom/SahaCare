import 'package:flutter/material.dart';

import '../../domain/entities/user_profile.dart';
import '../extensions/profile_enum_extensions.dart';
import 'date_labels.dart';
import '../../../../i18n/strings.g.dart';

/// Carte d'affichage de la démographie et du mode de vie.
class LifestyleCard extends StatelessWidget {
  const LifestyleCard({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _Row(Icons.event_outlined, t.birthDate, profile.dateOfBirth == null ? null : formatDate(profile.dateOfBirth!)),
      _Row(Icons.wc_rounded, t.biologicalSex, profile.sex?.localized),
      _Row(Icons.smoking_rooms_outlined, t.tobacco, profile.smoking?.localized),
      _Row(Icons.local_bar_outlined, t.alcohol, profile.alcohol?.localized),
      _Row(Icons.directions_run_rounded, t.physicalActivity, profile.activity?.localized),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1) const Divider(height: 1, indent: 56),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value ?? t.notSpecified,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: value == null ? theme.textTheme.bodyMedium?.color : null,
              fontStyle: value == null ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
