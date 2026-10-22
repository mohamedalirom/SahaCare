import 'package:geolocator/geolocator.dart';
import '../entities/nearby_place.dart';

/// Contrat du repository pour la recherche d'établissements de santé à proximité
abstract class NearbyRepository {
  /// Récupère les lieux de santé à proximité avec cache et tri par distance
  Future<List<NearbyPlace>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    bool forceRefresh = false,
  });

  /// Récupère la position géographique actuelle de l'utilisateur
  Future<Position> getCurrentPosition();

  /// Vérifie si les services de localisation sont activés sur l'appareil
  Future<bool> isLocationServiceEnabled();

  /// Vérifie le statut actuel de la permission de localisation
  Future<LocationPermission> checkPermission();

  /// Demande la permission de localisation à l'utilisateur
  Future<LocationPermission> requestPermission();

  /// Ouvre les paramètres système de l'application
  Future<bool> openAppSettings();

  /// Ouvre les paramètres système de géolocalisation
  Future<bool> openLocationSettings();
}
