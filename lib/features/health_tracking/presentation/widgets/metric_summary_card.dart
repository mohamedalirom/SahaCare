import 'package:flutter/material.dart';

import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/health_measurement.dart';
import 'health_line_chart.dart';
import 'measurement_status_badge.dart';

/// Carte de synthèse d'un type de mesure : dernière valeur, statut et mini-courbe
class MetricSummaryCard extends StatelessWidget {
  final MeasurementType type;
  final List<HealthMeasurement> measurements; // du plus récent au plus ancien
  final VoidCallback onTap;

  const MetricSummaryCard({super.key, required this.type, required this.measurements, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final latest = measurements.isNotEmpty ? measurements.first : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: type.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(type.icon, color: type.color, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            type.label,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            latest?.displayValue ?? '--',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(type.unit, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (latest != null)
                      Row(
                        children: [
                          MeasurementStatusBadge(status: latest.status),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              AppUtils.formatDate(latest.dateTime),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: HealthLineChart(
                  type: type,
                  measurements: measurements.take(10).toList(),
                  height: 64,
                  compact: true,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
