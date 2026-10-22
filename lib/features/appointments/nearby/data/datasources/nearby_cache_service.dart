import '../../domain/entities/nearby_place.dart';

class _CacheEntry {
  final List<NearbyPlace> places;
  final DateTime timestamp;

  _CacheEntry({required this.places, required this.timestamp});

  bool get isExpired {
    return DateTime.now().difference(timestamp) > const Duration(minutes: 30);
  }
}

/// Service de cache en mémoire pour les requêtes Overpass (TTL 30 min)
class NearbyCacheService {
  final Map<String, _CacheEntry> _cache = {};

  /// Génère une clé de cache basée sur les coordonnées arrondies (2 décimales) et le rayon
  static String generateKey({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) {
    // Arrondi à 2 décimales pour regrouper les requêtes très proches (~1.1 km)
    final latKey = latitude.toStringAsFixed(2);
    final lonKey = longitude.toStringAsFixed(2);
    return '${latKey}_${lonKey}_$radiusMeters';
  }

  /// Récupère les données en cache si valides et non expirées
  List<NearbyPlace>? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.places;
  }

  /// Stocke les lieux dans le cache
  void set(String key, List<NearbyPlace> places) {
    _cache[key] = _CacheEntry(
      places: List.unmodifiable(places),
      timestamp: DateTime.now(),
    );
  }

  /// Vide le cache
  void clear() {
    _cache.clear();
  }

  /// Nombre d'entrées en cache
  int get size => _cache.length;
}
