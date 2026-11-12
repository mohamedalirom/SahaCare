import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/health_measurement.dart';
import '../widgets/health_async_view.dart';
import '../widgets/measurement_tile.dart';
import '../widgets/measurement_type_picker_sheet.dart';
import '../widgets/metric_summary_card.dart';
import '../widgets/health_palette.dart';
import '../widgets/phone_frame_insets.dart';

/// Écran tableau de bord principal du module : Suivi de santé
class HealthDashboardScreen extends StatelessWidget {
  const HealthDashboardScreen({super.key});

  Future<void> _addMeasurement(BuildContext context) async {
    final type = await showMeasurementTypePicker(context);
    if (type != null && context.mounted) {
      context.push('/health-tracking/${type.name}/add');
    }
  }

  /// Hauteur occupée par la barre de navigation flottante (60) + sa marge (24)
  static const double _floatingNavBarHeight = 84;

  @override
  Widget build(BuildContext context) {
    return PhoneFrameInsets(
      child: Scaffold(
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
        // Surélevé pour rester au-dessus de la barre de navigation flottante
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: _floatingNavBarHeight),
          child: FloatingActionButton.extended(
            onPressed: () => _addMeasurement(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nouvelle mesure'),
          ),
        ),
        body: HealthAsyncView(builder: (measurements) => _buildContent(context, measurements)),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<HealthMeasurement> measurements) {
    final theme = Theme.of(context);
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final thisWeek = measurements.where((m) => m.dateTime.isAfter(weekAgo)).length;
    List<HealthMeasurement> ofType(MeasurementType t) => measurements.where((m) => m.type == t).toList();
    // Dernière valeur de chaque indicateur hors de la plage de référence
    final alerts = MeasurementType.values
        .map(ofType)
        .where((list) => list.isNotEmpty && list.first.status != MeasurementStatus.normal)
        .length;

    return ListView(
      // Espace en bas pour le bouton et la barre de navigation flottante
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96 + _floatingNavBarHeight),
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
              SizedBox(height: 4),
              Text(
                'Suivez l\'évolution de vos mesures au quotidien.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _SummaryStat(value: '$thisWeek', label: 'Mesures\ncette semaine'),
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
            measurements: ofType(type),
            onTap: () => context.push('/health-tracking/${type.name}'),
          ),
        ),
        const SizedBox(height: 12),

        const _SectionHeader(title: 'Dernières mesures'),
        const SizedBox(height: 10),
        if (measurements.isEmpty) EmptyMeasurementsMessage(),
        ...measurements
            .take(5)
            .map(
              (m) => MeasurementTile(
                measurement: m,
                showType: true,
                onTap: () => context.push('/health-tracking/${m.type.name}/${m.id}', extra: m),
              ),
            ),
        const SizedBox(height: 12),
        const Text(
          'ℹ️ Les plages indiquées sont informatives et ne remplacent pas l\'avis d\'un médecin.',
          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
        ),
      ],
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
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.healthText),
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
