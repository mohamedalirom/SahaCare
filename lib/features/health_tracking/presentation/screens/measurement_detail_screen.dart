import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/health_measurement.dart';
import '../controllers/health_tracking_controller.dart';
import '../widgets/measurement_actions.dart';
import '../widgets/measurement_status_badge.dart';
import '../widgets/health_palette.dart';
import '../widgets/phone_frame_insets.dart';

/// Détail d'une mesure de santé
class MeasurementDetailScreen extends ConsumerWidget {
  final String measurementId;
  final HealthMeasurement? initialMeasurement;

  const MeasurementDetailScreen({super.key, required this.measurementId, this.initialMeasurement});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, HealthMeasurement measurement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer la mesure ?'),
        content: Text('Cette mesure sera définitivement retirée de votre historique.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      // Le SnackBar « Annuler » reste visible sur l'écran précédent
      deleteMeasurementWithUndo(context, ref, measurement);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Version à jour (après modification) ; sinon celle transmise par la navigation
    final measurement = ref.watch(measurementByIdProvider(measurementId)) ?? initialMeasurement;
    if (measurement == null) {
      if (ref.watch(healthMeasurementsProvider).isLoading) {
        return PhoneFrameInsets(
          child: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      }
      return PhoneFrameInsets(
        child: Scaffold(
          appBar: AppBar(title: Text('Détail de la mesure')),
          body: Center(child: Text('Mesure introuvable')),
        ),
      );
    }
    final type = measurement.type;
    final editPath = '/health-tracking/${type.name}/${measurement.id}/edit';

    return PhoneFrameInsets(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Détail de la mesure'),
          actions: [
            IconButton(
              tooltip: 'Modifier la mesure',
              icon: Icon(Icons.edit_rounded),
              onPressed: () => context.push(editPath, extra: measurement),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Valeur principale
            Container(
              padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: type.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: type.color.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: context.healthSurface, shape: BoxShape.circle),
                    child: Icon(type.icon, color: type.color, size: 30),
                  ),
                  const SizedBox(height: 10),
                  Text(type.label, style: TextStyle(fontSize: 14, color: context.healthTextSecondary)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        measurement.displayValue,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: context.healthText,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(type.unit, style: TextStyle(fontSize: 16, color: context.healthTextSecondary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  MeasurementStatusBadge(status: measurement.status),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _InfoCard(
              children: [
                _InfoRow(
                  icon: Icons.event_rounded,
                  label: 'Date et heure',
                  value: AppUtils.formatDateTime(measurement.dateTime),
                ),
                if (measurement.glycemiaContext != null)
                  _InfoRow(icon: Icons.restaurant_rounded, label: 'Moment', value: measurement.glycemiaContext!.label),
                if (type == MeasurementType.weight)
                  _InfoRow(
                    icon: Icons.straighten_rounded,
                    label: 'IMC (taille ${HealthMeasurement.userHeight} m)',
                    value: (measurement.value / (HealthMeasurement.userHeight * HealthMeasurement.userHeight))
                        .toStringAsFixed(1),
                  ),
                _InfoRow(icon: Icons.rule_rounded, label: 'Plage de référence', value: type.normalRange),
              ],
            ),
            const SizedBox(height: 12),

            _InfoCard(
              children: [
                _InfoRow(
                  icon: Icons.notes_rounded,
                  label: 'Note',
                  value: measurement.note.isEmpty ? 'Aucune note' : measurement.note,
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context, ref, measurement),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Supprimer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(editPath, extra: measurement),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Modifier'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: context.healthTextSecondary, size: 20),
      title: Text(label, style: TextStyle(fontSize: 12, color: context.healthTextSecondary)),
      subtitle: Text(
        value,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.healthText),
      ),
    );
  }
}
