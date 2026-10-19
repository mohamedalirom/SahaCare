import '../entities/health_measurement.dart';

/// Contrat du repository pour les mesures de santé d'un utilisateur
abstract class HealthMeasurementRepository {
  /// Récupère toutes les mesures de l'utilisateur, de la plus récente à la plus ancienne (Read)
  Future<List<HealthMeasurement>> getMeasurements(String userId);

  /// Enregistre une nouvelle mesure (Create)
  Future<void> addMeasurement(String userId, HealthMeasurement measurement);

  /// Met à jour une mesure existante (Update)
  Future<void> updateMeasurement(String userId, HealthMeasurement measurement);

  /// Supprime définitivement une mesure (Delete)
  Future<void> deleteMeasurement(String userId, String id);
}
