import 'package:flutter/material.dart';

import '../../domain/entities/medication_stock.dart';
import 'medication_visuals.dart';
import 'dynamic_medication_bottle.dart';
import '../../domain/entities/medication_text_normalizer.dart';

class MedicationStockCard extends StatelessWidget {
  const MedicationStockCard({
    super.key,
    required this.stock,
    this.commercialPresentation,
    this.onConfigure,
    this.onReplenish,
    this.onCorrect,
    this.onHistory,
  });
  final MedicationStock? stock;
  final String? commercialPresentation;
  final VoidCallback? onConfigure;
  final VoidCallback? onReplenish;
  final VoidCallback? onCorrect;
  final VoidCallback? onHistory;

  static Color colorFor(StockAlert alert) => switch (alert) {
    StockAlert.empty || StockAlert.anomaly => const Color(0xFFDC2626),
    StockAlert.low => const Color(0xFFD97706),
    StockAlert.disabled => const Color(0xFF64748B),
    StockAlert.normal => const Color(0xFF0D9488),
  };

  @override
  Widget build(BuildContext context) {
    final value = stock;
    final color = colorFor(value?.alert ?? StockAlert.disabled);
    final alert = value?.alert ?? StockAlert.disabled;
    final scale = value == null
        ? 0
        : (value.remaining.milliUnits > value.referenceQuantity.milliUnits
              ? value.remaining.milliUnits
              : value.referenceQuantity.milliUnits);
    final level = value == null || !value.enabled || scale == 0
        ? 0.0
        : value.remaining.milliUnits / scale;
    final presentation = normalizeMedicationText(commercialPresentation ?? '');
    final tablets = RegExp(r'\bcomprimes?\b').hasMatch(presentation);
    final capsules = RegExp(r'\b(gelules?|capsules?)\b').hasMatch(presentation);
    final mismatch =
        value != null &&
        value.enabled &&
        tablets != capsules &&
        ((tablets && value.unit == StockUnit.capsule) ||
            (capsules && value.unit == StockUnit.tablet));
    final badge = switch (alert) {
      StockAlert.normal => 'Stock normal',
      StockAlert.low => 'Stock faible',
      StockAlert.empty => 'Stock critique · épuisé',
      StockAlert.anomaly => 'À régulariser',
      StockAlert.disabled => 'Suivi désactivé',
    };
    return MedicationSurface(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF0FAF7), Colors.white, Color(0xFFF2F8FC)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MA RÉSERVE SANTÉ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                        color: MedicationColors.teal,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Stock du médicament',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: MedicationColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.inventory_2_outlined,
                color: MedicationColors.teal,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 12),
          MedicationBadge(
            label: badge,
            color: color,
            icon: alert == StockAlert.normal
                ? Icons.verified_outlined
                : alert == StockAlert.disabled
                ? Icons.pause_circle_outline
                : Icons.info_outline_rounded,
          ),
          const SizedBox(height: 20),
          Center(
            child: DynamicMedicationBottle(
              currentQuantity: value?.remaining ?? StockQuantity(0),
              referenceQuantity: value?.referenceQuantity ?? StockQuantity(0),
              unit: value?.unit ?? StockUnit.tablet,
              lowThreshold: value?.lowThreshold ?? StockQuantity(0),
              enabled: value?.enabled ?? false,
              color: color,
              height: 190,
            ),
          ),
          const SizedBox(height: 8),
          if (value != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Quantité disponible',
                style: TextStyle(
                  fontSize: 12,
                  color: MedicationColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (value == null)
            const Text(
              'Suivi du stock désactivé. Aucune quantité n’est déduite de la posologie.',
            )
          else ...[
            Text(
              '${value.remaining.display} ${value.unit.label}',
              key: const ValueKey('stock-remaining'),
              style: TextStyle(
                fontSize: 32,
                height: 1.25,
                letterSpacing: -.8,
                fontWeight: FontWeight.w800,
                color: MedicationColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: level, end: level),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (_, animatedLevel, _) => LinearProgressIndicator(
                key: const ValueKey('stock-gauge'),
                value: animatedLevel,
                minHeight: 12,
                color: color,
                backgroundColor: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Échelle visuelle : ${StockQuantity(scale).display} ${value.unit.label}. Ce niveau ne décrit pas la capacité physique du flacon.',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: MedicationColors.muted,
              ),
            ),
            if (value.enabled && alert == StockAlert.normal && level <= .5)
              const Text(
                'Niveau intermédiaire',
                style: TextStyle(color: MedicationColors.muted, fontSize: 12),
              ),
            if (mismatch) ...[
              const SizedBox(height: 10),
              Text(
                'Présentation et unité à vérifier : $commercialPresentation / ${value.unit.label}. Aucune correction automatique.',
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (onConfigure != null)
                TextButton(
                  onPressed: onConfigure,
                  child: const Text('Vérifier les réglages du stock'),
                ),
            ],
            const SizedBox(height: 10),
            Text(
              'Par prise : ${value.unitsPerDose.display} ${value.unit.label}',
              style: const TextStyle(
                fontSize: 13,
                height: 1.7,
                color: MedicationColors.muted,
              ),
            ),
            Text(
              'Seuil d’alerte : ${value.lowThreshold.display} ${value.unit.label}',
              style: const TextStyle(
                fontSize: 13,
                height: 1.7,
                color: MedicationColors.muted,
              ),
            ),
            if (!value.enabled)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Suivi désactivé : cette quantité enregistrée n’est plus mise à jour par les prises.',
                ),
              ),
            if (value.enabled && value.alert != StockAlert.normal)
              Semantics(
                liveRegion: true,
                child: Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: .12)),
                  ),
                  child: Text(
                    value.pendingAnomalies > 0
                        ? '${value.pendingAnomalies} anomalie(s) : prise confirmée sans débit complet. Stock inchangé, à régulariser.'
                        : value.remaining.milliUnits == 0
                        ? 'Stock épuisé.'
                        : 'Stock faible : le seuil d’alerte est atteint.',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onConfigure != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: MedicationColors.teal,
                    backgroundColor: const Color(0xFFE3F3EF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: onConfigure,
                  icon: const Icon(Icons.tune),
                  label: Text(
                    value == null ? 'Activer le suivi' : 'Réglages du stock',
                  ),
                ),
              if (value != null) ...[
                TextButton.icon(
                  key: const ValueKey('stock-replenish'),
                  onPressed: onReplenish,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: MedicationColors.teal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Réapprovisionner'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: MedicationColors.ink,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    side: const BorderSide(color: MedicationColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: onCorrect,
                  child: const Text('Corriger la quantité'),
                ),
              ],
              if (onHistory != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: MedicationColors.muted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onPressed: onHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('Mouvements de stock'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
