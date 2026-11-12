import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/health_measurement.dart';
import '../controllers/health_tracking_controller.dart';

/// Supprime une mesure et propose « Annuler » dans un SnackBar.
/// Renvoie true si la suppression a réussi.
Future<bool> deleteMeasurementWithUndo(BuildContext context, WidgetRef ref, HealthMeasurement measurement) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(healthMeasurementsProvider.notifier);
  try {
    await notifier.delete(measurement.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Mesure de ${measurement.type.label.toLowerCase()} supprimée'),
          action: SnackBarAction(label: 'Annuler', onPressed: () => notifier.restore(measurement)),
        ),
      );
    return true;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Erreur lors de la suppression : $e'), backgroundColor: const Color(0xFFDC2626)),
    );
    return false;
  }
}
