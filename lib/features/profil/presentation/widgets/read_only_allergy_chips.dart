import 'package:flutter/material.dart';

import '../../domain/entities/medical_history.dart';

extension AllergySeverityStyle on AllergySeverity {
  Color get color => switch (this) {
        AllergySeverity.mild => const Color(0xFFF59E0B),
        AllergySeverity.moderate => const Color(0xFFF97316),
        AllergySeverity.severe => const Color(0xFFEF4444),
      };
}

IconData _kindIcon(AllergyKind kind) => switch (kind) {
      AllergyKind.medication => Icons.medication_outlined,
      AllergyKind.food => Icons.restaurant_outlined,
      AllergyKind.other => Icons.warning_amber_rounded,
    };

/// Allergies affichées sous forme de `Wrap` de `Chip` NON interactifs
/// (pas de `InputChip`, pas de `onDeleted`, pas d'`onPressed`).
class ReadOnlyAllergyChips extends StatelessWidget {
  const ReadOnlyAllergyChips({super.key, required this.allergies});

  final List<Allergy> allergies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final allergy in allergies)
              Chip(
                avatar: Icon(_kindIcon(allergy.kind), size: 18, color: allergy.severity.color),
                label: Text(allergy.name),
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                backgroundColor: allergy.severity.color.withValues(alpha: 0.14),
                side: BorderSide(color: allergy.severity.color.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final s in AllergySeverity.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(s.label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
