import 'package:flutter/material.dart';

import '../../domain/entities/health_measurement.dart';

/// Ligne de statistiques : minimum, moyenne, maximum
class MeasurementStatsRow extends StatelessWidget {
  final MeasurementType type;
  final List<HealthMeasurement> measurements;

  const MeasurementStatsRow({super.key, required this.type, required this.measurements});

  String _format(double v) => v.toStringAsFixed(type.decimals);

  @override
  Widget build(BuildContext context) {
    String min = '--', avg = '--', max = '--';
    if (measurements.isNotEmpty) {
      final values = measurements.map((m) => m.value).toList();
      min = _format(values.reduce((a, b) => a < b ? a : b));
      max = _format(values.reduce((a, b) => a > b ? a : b));
      avg = _format(values.reduce((a, b) => a + b) / values.length);
      if (type == MeasurementType.bloodPressure) {
        final dia = measurements.map((m) => m.secondaryValue ?? 0).toList();
        min = '$min/${_format(dia.reduce((a, b) => a < b ? a : b))}';
        max = '$max/${_format(dia.reduce((a, b) => a > b ? a : b))}';
        avg = '$avg/${_format(dia.reduce((a, b) => a + b) / dia.length)}';
      }
    }

    return Row(
      children: [
        _StatBox(label: 'Minimum', value: min, unit: type.unit),
        const SizedBox(width: 8),
        _StatBox(label: 'Moyenne', value: avg, unit: type.unit, highlight: true),
        const SizedBox(width: 8),
        _StatBox(label: 'Maximum', value: max, unit: type.unit),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final bool highlight;

  const _StatBox({required this.label, required this.value, required this.unit, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight ? primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight ? primary.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
            Text(unit, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}
