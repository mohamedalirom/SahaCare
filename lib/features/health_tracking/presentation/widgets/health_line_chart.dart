import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/health_measurement.dart';

/// Graphique linéaire de l'évolution d'une mesure de santé.
/// Pour la tension artérielle, deux courbes : systolique et diastolique.
class HealthLineChart extends StatelessWidget {
  final MeasurementType type;
  final List<HealthMeasurement> measurements;
  final double height;

  /// Mode compact (mini-courbe sans axes) pour les cartes du tableau de bord
  final bool compact;

  const HealthLineChart({
    super.key,
    required this.type,
    required this.measurements,
    this.height = 220,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (measurements.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Aucune mesure sur cette période', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ),
      );
    }

    // Ordre chronologique pour le tracé
    final sorted = [...measurements]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final origin = sorted.first.dateTime;
    double x(HealthMeasurement m) => m.dateTime.difference(origin).inHours / 24;

    final mainSpots = sorted.map((m) => FlSpot(x(m), m.value)).toList();
    final secondarySpots = type == MeasurementType.bloodPressure
        ? sorted.map((m) => FlSpot(x(m), m.secondaryValue ?? 0)).toList()
        : <FlSpot>[];

    final allValues = [...mainSpots, ...secondarySpots].map((s) => s.y);
    final minY = allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY) * 0.2).clamp(1.0, double.infinity);
    final maxX = mainSpots.last.x == 0 ? 1.0 : mainSpots.last.x;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY - padding,
          maxY: maxY + padding,
          gridData: FlGridData(
            show: !compact,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: compact ? const FlTitlesData(show: false) : _titles(origin, maxX),
          lineTouchData: LineTouchData(
            enabled: !compact,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF0F172A),
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      s.y.toStringAsFixed(type.decimals),
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            _bar(mainSpots, type.color),
            if (secondarySpots.isNotEmpty) _bar(secondarySpots, const Color(0xFF0284C7)),
          ],
        ),
      ),
    );
  }

  LineChartBarData _bar(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      preventCurveOverShooting: true,
      color: color,
      barWidth: compact ? 2 : 3,
      dotData: FlDotData(show: !compact && spots.length <= 15),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }

  FlTitlesData _titles(DateTime origin, double maxX) {
    const labelStyle = TextStyle(fontSize: 10, color: Color(0xFF94A3B8));
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          getTitlesWidget: (value, meta) {
            if (value == meta.min || value == meta.max) return const SizedBox.shrink();
            return Text(value.toStringAsFixed(type == MeasurementType.temperature ? 1 : 0), style: labelStyle);
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: (maxX / 4).clamp(1.0, double.infinity),
          getTitlesWidget: (value, meta) {
            final date = origin.add(Duration(hours: (value * 24).round()));
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(DateFormat('dd/MM').format(date), style: labelStyle),
            );
          },
        ),
      ),
    );
  }
}

/// Légende des deux courbes de tension artérielle
class BloodPressureLegend extends StatelessWidget {
  const BloodPressureLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 8),
      child: Row(
        children: [
          dot(MeasurementType.bloodPressure.color, 'Systolique'),
          const SizedBox(width: 16),
          dot(const Color(0xFF0284C7), 'Diastolique'),
        ],
      ),
    );
  }
}
