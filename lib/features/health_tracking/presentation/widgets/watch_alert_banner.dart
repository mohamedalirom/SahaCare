import 'package:flutter/material.dart';

import '../controllers/saha_intelligence_controller.dart';
import 'health_palette.dart';

/// Alerte affichée quand la montre connectée envoie une valeur inhabituelle
class WatchAlertBanner extends StatelessWidget {
  final WatchAlert alert;
  final VoidCallback onDismiss;

  const WatchAlertBanner({super.key, required this.alert, required this.onDismiss});

  static const Color _warning = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    final higher = alert.bpm > alert.baseline.mean;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: _warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fréquence cardiaque inhabituelle',
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.healthText),
                ),
                const SizedBox(height: 2),
                Text(
                  '${alert.bpm.round()} bpm relevés par la montre : ${higher ? 'plus haut' : 'plus bas'} que votre '
                  'plage habituelle (${alert.baseline.low.round()} – ${alert.baseline.high.round()} bpm). '
                  'Si cela persiste au repos, parlez-en à un professionnel de santé.',
                  style: TextStyle(fontSize: 12.5, color: context.healthTextSecondary, height: 1.35),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Fermer',
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
