import 'package:flutter/material.dart';

import '../../domain/entities/health_measurement.dart';

/// Badge indiquant l'interprétation d'une mesure (Bas / Normal / Élevé)
class MeasurementStatusBadge extends StatelessWidget {
  final MeasurementStatus status;

  const MeasurementStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case MeasurementStatus.low:
        bg = const Color(0xFFE0F2FE); // Bleu doux
        fg = const Color(0xFF0284C7);
        icon = Icons.south_rounded;
        break;
      case MeasurementStatus.normal:
        bg = const Color(0xFFDCFCE7); // Vert santé
        fg = const Color(0xFF16A34A);
        icon = Icons.check_circle_outline_rounded;
        break;
      case MeasurementStatus.high:
        bg = const Color(0xFFFEE2E2); // Rouge alerte
        fg = const Color(0xFFDC2626);
        icon = Icons.north_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
