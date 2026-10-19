import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/health_measurement.dart';
import '../controllers/health_tracking_controller.dart';
import '../widgets/health_async_view.dart';
import '../widgets/measurement_actions.dart';
import '../widgets/health_line_chart.dart';
import '../widgets/measurement_stats_row.dart';
import '../widgets/measurement_tile.dart';
import '../widgets/period_selector.dart';
import '../widgets/health_palette.dart';

/// Historique d'un type de mesure : graphique + liste des valeurs
class MeasurementHistoryScreen extends ConsumerStatefulWidget {
  final MeasurementType type;

  const MeasurementHistoryScreen({super.key, required this.type});

  @override
  ConsumerState<MeasurementHistoryScreen> createState() => _MeasurementHistoryScreenState();
}

class _MeasurementHistoryScreenState extends ConsumerState<MeasurementHistoryScreen> {
  ChartPeriod _period = ChartPeriod.month;

  List<HealthMeasurement> get _filtered {
    final from = DateTime.now().subtract(Duration(days: _period.days));
    return ref.watch(measurementsByTypeProvider(widget.type)).where((m) => m.dateTime.isAfter(from)).toList();
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
        child: Icon(Icons.add_rounded),
      ),
      body: HealthAsyncView(
        builder: (_) => ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            PeriodSelector(selected: _period, onChanged: (p) => setState(() => _period = p)),
            SizedBox(height: 16),
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
                            style: TextStyle(fontWeight: FontWeight.w600, color: context.healthText),
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
            SizedBox(height: 12),
            MeasurementStatsRow(type: type, measurements: measurements),
            SizedBox(height: 20),
            Text(
              'Historique (${measurements.length})',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.healthText),
            ),
            SizedBox(height: 10),
            if (measurements.isEmpty) EmptyMeasurementsMessage(message: 'Aucune mesure sur cette période.'),
            ...measurements.map(
              (m) => Dismissible(
                key: ValueKey(m.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                ),
                onDismissed: (_) => deleteMeasurementWithUndo(context, ref, m),
                child: MeasurementTile(
                  measurement: m,
                  onTap: () => context.push('/health-tracking/${type.name}/${m.id}', extra: m),
                ),
              ),
            ),
            if (measurements.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Astuce : faites glisser une mesure vers la gauche pour la supprimer.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
