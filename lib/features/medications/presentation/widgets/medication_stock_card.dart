import 'package:flutter/material.dart';

import '../../domain/entities/medication_stock.dart';

class MedicationStockCard extends StatelessWidget {
  const MedicationStockCard({
    super.key,
    required this.stock,
    this.onConfigure,
    this.onReplenish,
    this.onCorrect,
    this.onHistory,
  });
  final MedicationStock? stock;
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stock du médicament',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          if (value == null)
            const Text(
              'Suivi du stock désactivé. Aucune quantité n’est déduite de la posologie.',
            )
          else ...[
            Text(
              '${value.remaining.display} ${value.unit.label}',
              key: const ValueKey('stock-remaining'),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              key: const ValueKey('stock-gauge'),
              value: value.fraction,
              minHeight: 8,
              color: color,
              backgroundColor: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 10),
            Text(
              'Par prise : ${value.unitsPerDose.display} ${value.unit.label}',
            ),
            Text(
              'Seuil d’alerte : ${value.lowThreshold.display} ${value.unit.label}',
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
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    value.pendingAnomalies > 0
                        ? '${value.pendingAnomalies} anomalie(s) : prise confirmée sans débit complet. Stock inchangé, à régulariser.'
                        : value.remaining.milliUnits == 0
                        ? 'Stock épuisé.'
                        : 'Stock faible : le seuil d’alerte est atteint.',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (onConfigure != null)
                TextButton.icon(
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
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Réapprovisionner'),
                ),
                TextButton(
                  onPressed: onCorrect,
                  child: const Text('Corriger la quantité'),
                ),
              ],
              if (onHistory != null)
                TextButton.icon(
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
