import 'package:flutter/material.dart';
import '../../domain/entities/disease.dart';

/// Badge visuel indiquant le statut ou la sévérité d'une maladie
class DiseaseStatusBadge extends StatelessWidget {
  final DiseaseStatus status;

  const DiseaseStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status) {
      case DiseaseStatus.active:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case DiseaseStatus.inTreatment:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case DiseaseStatus.chronic:
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF4F46E5);
        break;
      case DiseaseStatus.recovered:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Badge visuel indiquant la gravité
class DiseaseSeverityBadge extends StatelessWidget {
  final DiseaseSeverity severity;

  const DiseaseSeverityBadge({
    super.key,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (severity) {
      case DiseaseSeverity.mild:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        break;
      case DiseaseSeverity.moderate:
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFEA580C);
        break;
      case DiseaseSeverity.severe:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            severity.label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
