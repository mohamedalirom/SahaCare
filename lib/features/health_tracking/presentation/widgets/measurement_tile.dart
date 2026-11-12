import 'package:flutter/material.dart';

import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/health_measurement.dart';
import 'measurement_status_badge.dart';
import 'health_palette.dart';

/// Ligne d'historique représentant une mesure
class MeasurementTile extends StatelessWidget {
  final HealthMeasurement measurement;
  final VoidCallback onTap;

  /// Afficher le nom du type (utile dans une liste mixte)
  final bool showType;

  const MeasurementTile({super.key, required this.measurement, required this.onTap, this.showType = false});

  @override
  Widget build(BuildContext context) {
    final type = measurement.type;
    final subtitle = [
      AppUtils.formatDateTime(measurement.dateTime),
      if (measurement.glycemiaContext != null) measurement.glycemiaContext!.label,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.healthBorder),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: type.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(type.icon, color: type.color, size: 20),
        ),
        title: Text(
          showType
              ? '${type.label} · ${measurement.displayValue} ${type.unit}'
              : '${measurement.displayValue} ${type.unit}',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.healthText),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: context.healthTextSecondary)),
        trailing: MeasurementStatusBadge(status: measurement.status),
      ),
    );
  }
}
