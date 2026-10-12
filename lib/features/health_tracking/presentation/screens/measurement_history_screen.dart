import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/health_measurement.dart';
import '../widgets/health_line_chart.dart';
import '../widgets/measurement_stats_row.dart';
import '../widgets/measurement_tile.dart';
import '../widgets/period_selector.dart';

/// Historique d'un type de mesure : graphique + liste des valeurs
class MeasurementHistoryScreen extends StatefulWidget {
  final MeasurementType type;

  const MeasurementHistoryScreen({super.key, required this.type});

  @override
  State<MeasurementHistoryScreen> createState() => _MeasurementHistoryScreenState();
}

class _MeasurementHistoryScreenState extends State<MeasurementHistoryScreen> {
  ChartPeriod _period = ChartPeriod.month;

  List<HealthMeasurement> get _filtered {
    final from = DateTime.now().subtract(Duration(days: _period.days));
    return HealthMeasurement.byType(widget.type).where((m) => m.dateTime.isAfter(from)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final measurements = _filtered;

    return Scaffold(
      appBar: AppBar(title: Text(type.label)),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter une mesure',
        onPressed: () => context.push('/health-tracking/${type.name}/add'),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          PeriodSelector(selected: _period, onChanged: (p) => setState(() => _period = p)),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Row(
                      children: [
                        Icon(type.icon, color: type.color, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Évolution (${type.unit})',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                  HealthLineChart(type: type, measurements: measurements),
                  if (type == MeasurementType.bloodPressure) const BloodPressureLegend(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          MeasurementStatsRow(type: type, measurements: measurements),
          const SizedBox(height: 20),
          Text(
            'Historique (${measurements.length})',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          ...measurements.map(
            (m) => MeasurementTile(measurement: m, onTap: () => context.push('/health-tracking/${type.name}/${m.id}')),
          ),
        ],
      ),
    );
  }
}
