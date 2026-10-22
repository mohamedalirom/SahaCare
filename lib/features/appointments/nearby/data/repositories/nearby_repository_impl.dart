import 'package:geolocator/geolocator.dart';
import '../../domain/entities/nearby_place.dart';
import '../../domain/repositories/nearby_repository.dart';
import '../datasources/location_service.dart';
import '../datasources/nearby_cache_service.dart';
import '../datasources/overpass_service.dart';

class NearbyRepositoryImpl implements NearbyRepository {
  final LocationService _locationService;
  final OverpassService _overpassService;
  final NearbyCacheService _cacheService;

  NearbyRepositoryImpl({
    LocationService? locationService,
    OverpassService? overpassService,
    NearbyCacheService? cacheService,
  })  : _locationService = locationService ?? LocationService(),
        _overpassService = overpassService ?? OverpassService(),
        _cacheService = cacheService ?? NearbyCacheService();

  @override
  Future<List<NearbyPlace>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    bool forceRefresh = false,
  }) async {
    final cacheKey = NearbyCacheService.generateKey(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );

    if (!forceRefresh) {
      final cached = _cacheService.get(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    final places = await _overpassService.fetchNearbyPlaces(
      userLat: latitude,
      userLon: longitude,
      radiusMeters: radiusMeters,
    );

    _cacheService.set(cacheKey, places);
    return places;
  }

  @override
  Future<Position> getCurrentPosition() {
    return _locationService.getCurrentPosition();
  }

  @override
  Future<bool> isLocationServiceEnabled() {
    return _locationService.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return _locationService.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() {
    return _locationService.requestPermission();
  }

  @override
  Future<bool> openAppSettings() {
    return _locationService.openAppSettings();
  }

  @override
  Future<bool> openLocationSettings() {
    return _locationService.openLocationSettings();
  }
}
