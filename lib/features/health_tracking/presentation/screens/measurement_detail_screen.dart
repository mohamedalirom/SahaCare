import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/health_measurement.dart';
import '../widgets/measurement_status_badge.dart';

/// Détail d'une mesure de santé
class MeasurementDetailScreen extends StatelessWidget {
  final String measurementId;
  final HealthMeasurement? initialMeasurement;

  const MeasurementDetailScreen({super.key, required this.measurementId, this.initialMeasurement});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la mesure ?'),
        content: const Text('Cette mesure sera définitivement retirée de votre historique.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Mesure supprimée (démo — pas encore connectée)')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final measurement = initialMeasurement ?? HealthMeasurement.findById(measurementId);
    if (measurement == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détail de la mesure')),
        body: const Center(child: Text('Mesure introuvable')),
      );
    }
    final type = measurement.type;
    final editPath = '/health-tracking/${type.name}/${measurement.id}/edit';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de la mesure'),
        actions: [
          IconButton(
            tooltip: 'Modifier la mesure',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push(editPath, extra: measurement),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Valeur principale
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: type.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: type.color.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(type.icon, color: type.color, size: 30),
                ),
                const SizedBox(height: 10),
                Text(type.label, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      measurement.displayValue,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(type.unit, style: const TextStyle(fontSize: 16, color: Color(0xFF64748B))),
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
                  onPressed: () => _confirmDelete(context),
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
      leading: Icon(icon, color: const Color(0xFF64748B), size: 20),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
      ),
    );
  }
}
