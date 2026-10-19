import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/health_measurement.dart';
import '../controllers/health_tracking_controller.dart';
import '../widgets/health_async_view.dart';
import '../widgets/health_line_chart.dart';
import '../widgets/measurement_stats_row.dart';
import '../widgets/period_selector.dart';
import '../widgets/health_palette.dart';

/// Statistiques : graphiques de tous les indicateurs, un onglet par type
class HealthStatisticsScreen extends ConsumerStatefulWidget {
  const HealthStatisticsScreen({super.key});

  @override
  ConsumerState<HealthStatisticsScreen> createState() => _HealthStatisticsScreenState();
}

class _HealthStatisticsScreenState extends ConsumerState<HealthStatisticsScreen> {
  ChartPeriod _period = ChartPeriod.threeMonths;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: MeasurementType.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Statistiques santé'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: context.healthTextSecondary,
            indicatorColor: theme.colorScheme.primary,
            indicatorWeight: 3,
            tabs: MeasurementType.values.map((t) => Tab(icon: Icon(t.icon, size: 20), text: t.label)).toList(),
          ),
        ),
        body: HealthAsyncView(builder: (_) => TabBarView(children: MeasurementType.values.map(_buildTab).toList())),
      ),
    );
  }

  Widget _buildTab(MeasurementType type) {
    final from = DateTime.now().subtract(Duration(days: _period.days));
    final measurements = ref.watch(measurementsByTypeProvider(type)).where((m) => m.dateTime.isAfter(from)).toList();
    final outOfRange = measurements.where((m) => m.status != MeasurementStatus.normal).length;

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        PeriodSelector(selected: _period, onChanged: (p) => setState(() => _period = p)),
        SizedBox(height: 16),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: Column(
              children: [
                HealthLineChart(type: type, measurements: measurements, height: 260),
                if (type == MeasurementType.bloodPressure) const BloodPressureLegend(),
              ],
            ),
          ),
        ),
        SizedBox(height: 12),
        MeasurementStatsRow(type: type, measurements: measurements),
        SizedBox(height: 12),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.format_list_numbered_rounded, color: context.healthTextSecondary),
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
                leading: Icon(Icons.history_rounded, color: context.healthTextSecondary),
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
