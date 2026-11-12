import 'package:geolocator/geolocator.dart';

/// Exception personnalisée pour les erreurs de géolocalisation
class LocationCustomException implements Exception {
  final String message;
  final LocationErrorType type;

  const LocationCustomException(this.message, this.type);

  @override
  String toString() => message;
}

enum LocationErrorType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

/// Service gérant la localisation et les permissions de l'appareil
class LocationService {
  /// Position de secours par défaut (Sousse, Tunisie)
  static final Position fallbackPosition = Position(
    latitude: 35.8256,
    longitude: 10.63699,
    timestamp: DateTime(2026, 1, 1),
    accuracy: 10.0,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: 0.0,
    speedAccuracy: 1.0,
  );

  /// Vérifie si les services de localisation (GPS) sont activés
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Vérifie la permission actuelle
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Demande la permission à l'utilisateur
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Récupère la position géographique actuelle
  Future<Position> getCurrentPosition({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationCustomException(
        'Le service de localisation (GPS) est désactivé.',
        LocationErrorType.serviceDisabled,
      );
    }

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationCustomException(
          'La permission de localisation a été refusée.',
          LocationErrorType.permissionDenied,
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationCustomException(
        'La permission de localisation est définitivement refusée. Veuillez l\'activer dans les paramètres.',
        LocationErrorType.permissionDeniedForever,
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
    } catch (e) {
      // Tentative avec la dernière position connue
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return lastKnown;
        }
      } catch (_) {}

      throw LocationCustomException(
        'Impossible de récupérer votre position actuelle : $e',
        LocationErrorType.timeout,
      );
    }
  }

  /// Ouvre les paramètres de l'application
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Ouvre les paramètres de localisation du système
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}
