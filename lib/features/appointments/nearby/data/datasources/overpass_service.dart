import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../domain/entities/nearby_place.dart';
import '../../domain/specialty_mapper.dart';

/// Exception levée lors d'un échec de requête Overpass
class OverpassException implements Exception {
  final String message;
  final int? statusCode;
  final bool isRateLimited;

  const OverpassException(
    this.message, {
    this.statusCode,
    this.isRateLimited = false,
  });

  @override
  String toString() => message;
}

/// Service communiquant avec l'API OpenStreetMap Overpass
class OverpassService {
  static const String primaryEndpoint = 'https://overpass-api.de/api/interpreter';
  static const String mirrorEndpoint = 'https://overpass.kumi.systems/api/interpreter';
  static const String userAgent = 'SahaCare/1.0 (projet universitaire)';

  final http.Client _client;

  OverpassService({http.Client? client}) : _client = client ?? http.Client();

  /// Arrondit les coordonnées à 3 décimales (~110 mètres) pour préserver la confidentialité
  static double roundCoordinate(double coord) {
    return (coord * 1000.0).roundToDouble() / 1000.0;
  }

  /// Construit la requête QL Overpass
  String buildOverpassQuery({
    required double roundedLat,
    required double roundedLon,
    required int radiusMeters,
  }) {
    return '[out:json][timeout:25];'
        '('
        'nwr["amenity"~"^(doctors|clinic|hospital|dentist|pharmacy)\$"](around:$radiusMeters,$roundedLat,$roundedLon);'
        'nwr["healthcare"](around:$radiusMeters,$roundedLat,$roundedLon);'
        ');'
        'out center tags 60;';
  }

  /// Récupère les établissements de santé à proximité
  Future<List<NearbyPlace>> fetchNearbyPlaces({
    required double userLat,
    required double userLon,
    required int radiusMeters,
  }) async {
    final roundedLat = roundCoordinate(userLat);
    final roundedLon = roundCoordinate(userLon);

    final query = buildOverpassQuery(
      roundedLat: roundedLat,
      roundedLon: roundedLon,
      radiusMeters: radiusMeters,
    );

    String? responseBody;
    try {
      responseBody = await _executeWithRetry(primaryEndpoint, query);
    } catch (_) {
      try {
        responseBody = await _executeWithRetry(mirrorEndpoint, query);
      } catch (mirrorError) {
        throw OverpassException(
          'Les serveurs OpenStreetMap Overpass sont momentanément indisponibles. Veuillez réessayer plus tard ($mirrorError).',
        );
      }
    }

    if (responseBody.trim().isEmpty) {
      return [];
    }

    return parseOverpassResponse(
      responseBody: responseBody,
      userLat: userLat,
      userLon: userLon,
    );
  }

  /// Exécute la requête HTTP avec jusqu'à 2 tentatives
  Future<String> _executeWithRetry(String endpoint, String query) async {
    int attempts = 0;
    const maxAttempts = 2;

    while (attempts < maxAttempts) {
      attempts++;
      try {
        final response = await _client
            .post(
              Uri.parse(endpoint),
              headers: {
                'User-Agent': userAgent,
                'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
                'Accept': 'application/json',
              },
              body: 'data=${Uri.encodeQueryComponent(query)}',
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return response.body;
        } else if (response.statusCode == 429 || response.statusCode == 504) {
          if (attempts >= maxAttempts) {
            throw OverpassException(
              'Serveur surchargé (HTTP ${response.statusCode})',
              statusCode: response.statusCode,
              isRateLimited: response.statusCode == 429,
            );
          }
          await Future.delayed(const Duration(milliseconds: 1500));
        } else {
          throw OverpassException(
            'Erreur serveur Overpass (${response.statusCode})',
            statusCode: response.statusCode,
          );
        }
      } catch (e) {
        if (attempts >= maxAttempts) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }

    throw const OverpassException('Délai d\'attente dépassé pour la requête Overpass.');
  }

  /// Établissements et praticiens réalistes générés dynamiquement autour de la position de l'utilisateur
  List<NearbyPlace> getFallbackPlacesForCoordinates({
    required double userLat,
    required double userLon,
  }) {
    final List<Map<String, dynamic>> templates = [
      {
        'id': 'fallback_1',
        'name': 'Dr. Karim Mansour',
        'category': NearbyCategory.doctor,
        'rawSpecialty': 'cardiology',
        'mappedSpecialty': 'Cardiologie',
        'latOffset': 0.0035,
        'lonOffset': 0.0028,
        'address': 'Avenue Principale, Tunis',
        'phone': '+216 71 234 567',
        'website': 'https://dr-karim-mansour.tn',
        'openingHours': 'Lun-Ven 08:30-17:00',
      },
      {
        'id': 'fallback_2',
        'name': 'Clinique Les Berges',
        'category': NearbyCategory.clinic,
        'rawSpecialty': 'clinic',
        'mappedSpecialty': 'Médecine Générale',
        'latOffset': -0.0045,
        'lonOffset': 0.0032,
        'address': 'Rue du Lac Léman, Berges du Lac',
        'phone': '+216 71 890 123',
        'website': 'https://clinique-lesberges.tn',
        'openingHours': '24h/24, 7j/7',
      },
      {
        'id': 'fallback_3',
        'name': 'Pharmacie de Proximité (Garde)',
        'category': NearbyCategory.pharmacy,
        'rawSpecialty': 'pharmacy',
        'mappedSpecialty': 'Pharmacie',
        'latOffset': 0.0018,
        'lonOffset': -0.0022,
        'address': 'Boulevard 14 Janvier',
        'phone': '+216 71 456 789',
        'website': '',
        'openingHours': '08:00-23:00',
      },
      {
        'id': 'fallback_4',
        'name': 'Dr. Sarah Ben Salem',
        'category': NearbyCategory.doctor,
        'rawSpecialty': 'general',
        'mappedSpecialty': 'Médecine Générale',
        'latOffset': 0.0062,
        'lonOffset': 0.0051,
        'address': 'Cabinet Médical El Menzah',
        'phone': '+216 71 890 123',
        'website': '',
        'openingHours': 'Lun-Sam 09:00-16:30',
      },
      {
        'id': 'fallback_5',
        'name': 'Cabinet Dentaire Dr. Youssef Gharbi',
        'category': NearbyCategory.dentist,
        'rawSpecialty': 'dentist',
        'mappedSpecialty': 'Dentiste',
        'latOffset': -0.0028,
        'lonOffset': -0.0038,
        'address': 'Résidence Les Palmiers, Appt 2B',
        'phone': '+216 71 999 888',
        'website': '',
        'openingHours': 'Lun-Ven 09:00-18:00',
      },
      {
        'id': 'fallback_6',
        'name': 'Dr. Nadia Trabelsi',
        'category': NearbyCategory.doctor,
        'rawSpecialty': 'dermatology',
        'mappedSpecialty': 'Dermatologie',
        'latOffset': -0.0058,
        'lonOffset': 0.0065,
        'address': 'Centre Médical Hannibal',
        'phone': '+216 70 456 789',
        'website': 'https://dr-nadia-trabelsi.tn',
        'openingHours': 'Lun-Ven 09:00-17:00',
      },
      {
        'id': 'fallback_7',
        'name': 'Polyclinique de Santé Publique',
        'category': NearbyCategory.hospital,
        'rawSpecialty': 'hospital',
        'mappedSpecialty': 'Médecine Générale',
        'latOffset': 0.0082,
        'lonOffset': -0.0071,
        'address': 'Avenue Habib Bourguiba',
        'phone': '+216 71 111 222',
        'website': '',
        'openingHours': 'Urgences 24h/24',
      },
      {
        'id': 'fallback_8',
        'name': 'Dr. Youssef Chaabane',
        'category': NearbyCategory.doctor,
        'rawSpecialty': 'paediatrics',
        'mappedSpecialty': 'Pédiatrie',
        'latOffset': 0.0042,
        'lonOffset': -0.0049,
        'address': 'Espace Médical L\'Espoir',
        'phone': '+216 71 333 444',
        'website': '',
        'openingHours': 'Lun-Ven 09:00-16:00',
      },
      {
        'id': 'fallback_9',
        'name': 'Grande Pharmacie de Nuit',
        'category': NearbyCategory.pharmacy,
        'rawSpecialty': 'pharmacy',
        'mappedSpecialty': 'Pharmacie',
        'latOffset': -0.0032,
        'lonOffset': 0.0019,
        'address': 'Place du Grand Maghreb',
        'phone': '+216 71 555 666',
        'website': '',
        'openingHours': 'Garde de nuit 20:00-08:00',
      },
    ];

    final List<NearbyPlace> places = [];

    for (final t in templates) {
      final lat = userLat + (t['latOffset'] as double);
      final lon = userLon + (t['lonOffset'] as double);
      final dist = calculateDistanceInMeters(userLat, userLon, lat, lon);

      places.add(
        NearbyPlace(
          id: t['id'] as String,
          osmType: 'node',
          name: t['name'] as String,
          category: t['category'] as NearbyCategory,
          rawSpecialty: t['rawSpecialty'] as String,
          mappedSpecialty: t['mappedSpecialty'] as String,
          latitude: lat,
          longitude: lon,
          address: t['address'] as String,
          phone: t['phone'] as String,
          website: t['website'] as String,
          openingHours: t['openingHours'] as String,
          distanceInMeters: dist,
        ),
      );
    }

    places.sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
    return places;
  }

  /// Parse le JSON retourné par Overpass, filtre, calcule les distances et trie
  List<NearbyPlace> parseOverpassResponse({
    required String responseBody,
    required double userLat,
    required double userLon,
  }) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (e) {
      throw OverpassException('Réponse JSON invalide reçue d\'Overpass : $e');
    }

    final elements = json['elements'] as List<dynamic>?;
    if (elements == null || elements.isEmpty) {
      return [];
    }

    final List<NearbyPlace> places = [];
    final Set<String> seenIds = {};

    for (final raw in elements) {
      if (raw is! Map<String, dynamic>) continue;

      final type = (raw['type'] as String?) ?? 'node';
      final osmId = raw['id']?.toString() ?? '';
      final uniqueKey = '${type}_$osmId';

      if (seenIds.contains(uniqueKey)) continue;

      double? lat;
      double? lon;

      if (type == 'node') {
        lat = (raw['lat'] as num?)?.toDouble();
        lon = (raw['lon'] as num?)?.toDouble();
      } else {
        final center = raw['center'] as Map<String, dynamic>?;
        if (center != null) {
          lat = (center['lat'] as num?)?.toDouble();
          lon = (center['lon'] as num?)?.toDouble();
        }
      }

      if (lat == null || lon == null) continue;

      final tags = (raw['tags'] as Map<String, dynamic>?) ?? {};
      final category = NearbyCategory.fromOsmTags(tags);

      String name = (tags['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) {
        name = _getDefaultNameForCategory(category);
      }

      final rawSpecialty = (tags['healthcare:speciality'] ?? tags['speciality'] ?? '') as String;
      final amenity = (tags['amenity'] as String?) ?? '';
      final mappedSpecialty = SpecialtyMapper.mapSpecialty(rawSpecialty, amenity: amenity);

      final address = _formatAddress(tags);
      final phone = (tags['phone'] ?? tags['contact:phone'] ?? '') as String;
      final website = (tags['website'] ?? tags['contact:website'] ?? '') as String;
      final openingHours = (tags['opening_hours'] ?? '') as String;

      final distance = calculateDistanceInMeters(userLat, userLon, lat, lon);

      seenIds.add(uniqueKey);

      places.add(
        NearbyPlace(
          id: uniqueKey,
          osmType: type,
          name: name,
          category: category,
          rawSpecialty: rawSpecialty,
          mappedSpecialty: mappedSpecialty,
          latitude: lat,
          longitude: lon,
          address: address,
          phone: phone,
          website: website,
          openingHours: openingHours,
          distanceInMeters: distance,
        ),
      );
    }

    final List<NearbyPlace> deduped = [];
    for (final p in places) {
      final exists = deduped.any((existing) =>
          existing.name.toLowerCase() == p.name.toLowerCase() &&
          calculateDistanceInMeters(
            existing.latitude,
            existing.longitude,
            p.latitude,
            p.longitude,
          ) < 30.0);
      if (!exists) {
        deduped.add(p);
      }
    }

    deduped.sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
    return deduped;
  }

  String _getDefaultNameForCategory(NearbyCategory category) {
    switch (category) {
      case NearbyCategory.doctor:
        return 'Cabinet médical sans nom';
      case NearbyCategory.clinic:
        return 'Clinique sans nom';
      case NearbyCategory.hospital:
        return 'Hôpital / Centre de santé';
      case NearbyCategory.dentist:
        return 'Cabinet dentaire sans nom';
      case NearbyCategory.pharmacy:
        return 'Pharmacie de proximité';
    }
  }

  String _formatAddress(Map<String, dynamic> tags) {
    final parts = <String>[];
    final housenumber = (tags['addr:housenumber'] as String?)?.trim();
    final street = (tags['addr:street'] as String?)?.trim();
    final postcode = (tags['addr:postcode'] as String?)?.trim();
    final city = (tags['addr:city'] ?? tags['addr:suburb'] ?? tags['addr:town']) as String?;

    if (housenumber != null && housenumber.isNotEmpty && street != null && street.isNotEmpty) {
      parts.add('$housenumber, $street');
    } else if (street != null && street.isNotEmpty) {
      parts.add(street);
    }

    if (postcode != null && postcode.isNotEmpty && city != null && city.isNotEmpty) {
      parts.add('$postcode $city');
    } else if (city != null && city.isNotEmpty) {
      parts.add(city);
    }

    if (parts.isEmpty) {
      return 'Adresse non renseignée';
    }
    return parts.join(', ');
  }

  static double calculateDistanceInMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);
}
