import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/health_measurement.dart';
import '../widgets/health_line_chart.dart';
import '../widgets/measurement_stats_row.dart';
import '../widgets/period_selector.dart';

/// Statistiques : graphiques de tous les indicateurs, un onglet par type
class HealthStatisticsScreen extends StatefulWidget {
  const HealthStatisticsScreen({super.key});

  @override
  State<HealthStatisticsScreen> createState() => _HealthStatisticsScreenState();
}

class _HealthStatisticsScreenState extends State<HealthStatisticsScreen> {
  ChartPeriod _period = ChartPeriod.threeMonths;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: MeasurementType.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistiques santé'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: theme.colorScheme.primary,
            indicatorWeight: 3,
            tabs: MeasurementType.values.map((t) => Tab(icon: Icon(t.icon, size: 20), text: t.label)).toList(),
          ),
        ),
        body: TabBarView(children: MeasurementType.values.map(_buildTab).toList()),
      ),
    );
  }

  Widget _buildTab(MeasurementType type) {
    final from = DateTime.now().subtract(Duration(days: _period.days));
    final measurements = HealthMeasurement.byType(type).where((m) => m.dateTime.isAfter(from)).toList();
    final outOfRange = measurements.where((m) => m.status != MeasurementStatus.normal).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PeriodSelector(selected: _period, onChanged: (p) => setState(() => _period = p)),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: Column(
              children: [
                HealthLineChart(type: type, measurements: measurements, height: 260),
                if (type == MeasurementType.bloodPressure) const BloodPressureLegend(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        MeasurementStatsRow(type: type, measurements: measurements),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.format_list_numbered_rounded, color: Color(0xFF64748B)),
                title: const Text('Nombre de mesures', style: TextStyle(fontSize: 13)),
                trailing: Text(
                  '${measurements.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: outOfRange > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                ),
                title: const Text('Valeurs hors plage', style: TextStyle(fontSize: 13)),
                trailing: Text('$outOfRange', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history_rounded, color: Color(0xFF64748B)),
                title: const Text('Voir l\'historique complet', style: TextStyle(fontSize: 13)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/health-tracking/${type.name}'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
