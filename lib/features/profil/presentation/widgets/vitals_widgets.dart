import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_controller.dart';
import '../../domain/entities/user_profile.dart';
import 'bmi_gauge.dart';
import '../../../../i18n/strings.g.dart';

/// Tuile compacte d'un indicateur vital (groupe sanguin, taille, poids, âge).
class VitalTile extends StatelessWidget {
  const VitalTile({super.key, required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grille 2×2 des signes vitaux d'un profil.
class VitalsGrid extends ConsumerWidget {
  const VitalsGrid({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final isMetric = settings.isMetric;

    String fmt(double? v, String unitMetric, String unitImp, double Function(double) conv) {
      if (v == null) return '—';
      final val = isMetric ? v : conv(v);
      final unit = isMetric ? unitMetric : unitImp;
      return '${val.toStringAsFixed(val % 1 == 0 ? 0 : 1)} $unit';
    }

    final tiles = [
      VitalTile(
        label: t.bloodGroup,
        value: profile.bloodType ?? '—',
        icon: Icons.bloodtype,
        color: const Color(0xFFEF4444),
      ),
      VitalTile(
        label: t.age,
        value: profile.age == null ? '—' : '${profile.age} ${t.yearsOld}',
        icon: Icons.cake_outlined,
        color: const Color(0xFF8B5CF6),
      ),
      VitalTile(
        label: t.height,
        value: fmt(profile.heightCm, 'cm', 'in', SettingsController.cmToInches),
        icon: Icons.height,
        color: const Color(0xFF3B82F6),
      ),
      VitalTile(
        label: t.weight,
        value: fmt(profile.weightKg, 'kg', 'lbs', SettingsController.kgToLbs),
        icon: Icons.monitor_weight_outlined,
        color: const Color(0xFFF59E0B),
      ),
    ];

    final width = MediaQuery.of(context).size.width;
    final ratio = width < 360 ? 1.0 : 1.15;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: ratio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: tiles,
    );
  }
}

/// Carte « Indice de masse corporelle » avec jauge colorée.
class BmiCard extends StatelessWidget {
  const BmiCard({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.bmi,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(child: BmiGauge(bmi: profile.bmi)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final c in BmiCategory.values) _Legend(color: c.color, label: c.localized),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11)),
      ],
    );
  }
}
