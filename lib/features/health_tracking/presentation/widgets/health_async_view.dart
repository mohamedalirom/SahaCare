import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/health_measurement.dart';
import '../controllers/health_tracking_controller.dart';
import 'health_palette.dart';

/// Affiche un indicateur de chargement ou un message d'erreur tant que
/// les mesures ne sont pas disponibles, puis construit [builder].
class HealthAsyncView extends ConsumerWidget {
  final Widget Function(List<HealthMeasurement> measurements) builder;

  const HealthAsyncView({super.key, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(healthMeasurementsProvider);
    // Pendant un rechargement, on garde les données déjà affichées
    if (async.hasValue) return builder(async.value!);
    if (async.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(
                'Impossible de charger vos mesures',
                style: TextStyle(fontWeight: FontWeight.w600, color: context.healthText),
              ),
              const SizedBox(height: 4),
              Text(
                '${async.error}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.healthTextSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(healthMeasurementsProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    return Center(child: CircularProgressIndicator());
  }
}

/// Message affiché quand une liste de mesures est vide
class EmptyMeasurementsMessage extends StatelessWidget {
  final String message;

  const EmptyMeasurementsMessage({super.key, this.message = 'Aucune mesure enregistrée pour le moment.'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: context.healthSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.healthBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: Color(0xFF94A3B8), size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.healthTextSecondary),
          ),
        ],
      ),
    );
  }
}
