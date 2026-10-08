import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/health_measurement.dart';
import '../widgets/measurement_tile.dart';
import '../widgets/measurement_type_picker_sheet.dart';
import '../widgets/metric_summary_card.dart';

/// Écran tableau de bord principal du module : Suivi de santé
class HealthDashboardScreen extends StatelessWidget {
  const HealthDashboardScreen({super.key});

  Future<void> _addMeasurement(BuildContext context) async {
    final type = await showMeasurementTypePicker(context);
    if (type != null && context.mounted) {
      context.push('/health-tracking/${type.name}/add');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final measurements = HealthMeasurement.mockMeasurements;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final thisWeek = measurements.where((m) => m.dateTime.isAfter(weekAgo)).toList();
    final alerts = MeasurementType.values
        .map((t) => HealthMeasurement.byType(t).first)
        .where((m) => m.status != MeasurementStatus.normal)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi de santé'),
        actions: [
          IconButton(
            tooltip: 'Statistiques',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => context.push('/health-tracking/stats'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addMeasurement(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle mesure'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          // Carte de synthèse
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mon aperçu santé',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Suivez l\'évolution de vos mesures au quotidien.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _SummaryStat(value: '${thisWeek.length}', label: 'Mesures\ncette semaine'),
                    const SizedBox(width: 10),
                    _SummaryStat(value: '${MeasurementType.values.length}', label: 'Indicateurs\nsuivis'),
                    const SizedBox(width: 10),
                    _SummaryStat(value: '$alerts', label: 'Valeurs hors\nplage'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _SectionHeader(
            title: 'Mes indicateurs',
            actionLabel: 'Graphiques',
            onAction: () => context.push('/health-tracking/stats'),
          ),
          const SizedBox(height: 10),
          ...MeasurementType.values.map(
            (type) => MetricSummaryCard(
              type: type,
              measurements: HealthMeasurement.byType(type),
              onTap: () => context.push('/health-tracking/${type.name}'),
            ),
          ),
          const SizedBox(height: 12),

          const _SectionHeader(title: 'Dernières mesures'),
          const SizedBox(height: 10),
          ...measurements
              .take(5)
              .map(
                (m) => MeasurementTile(
                  measurement: m,
                  showType: true,
                  onTap: () => context.push('/health-tracking/${m.type.name}/${m.id}'),
                ),
              ),
          const SizedBox(height: 12),
          const Text(
            'ℹ️ Les plages indiquées sont informatives et ne remplacent pas l\'avis d\'un médecin.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white, height: 1.25)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.show_chart_rounded, size: 18),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}
