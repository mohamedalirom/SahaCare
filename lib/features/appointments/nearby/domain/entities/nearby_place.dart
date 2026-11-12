import 'package:latlong2/latlong.dart';

/// Catégorie d'un lieu médical à proximité
enum NearbyCategory {
  doctor,
  clinic,
  hospital,
  dentist,
  pharmacy;

  /// Libellé en français par défaut
  String get labelFr {
    switch (this) {
      case NearbyCategory.doctor:
        return 'Médecin';
      case NearbyCategory.clinic:
        return 'Clinique';
      case NearbyCategory.hospital:
        return 'Hôpital';
      case NearbyCategory.dentist:
        return 'Dentiste';
      case NearbyCategory.pharmacy:
        return 'Pharmacie';
    }
  }

  /// Convertit une valeur OSM en catégorie
  static NearbyCategory fromOsmTags(Map<String, dynamic> tags) {
    final amenity = (tags['amenity'] as String?)?.toLowerCase();
    final healthcare = (tags['healthcare'] as String?)?.toLowerCase();

    if (amenity == 'pharmacy' || healthcare == 'pharmacy') {
      return NearbyCategory.pharmacy;
    }
    if (amenity == 'dentist' || healthcare == 'dentist') {
      return NearbyCategory.dentist;
    }
    if (amenity == 'hospital' || healthcare == 'hospital') {
      return NearbyCategory.hospital;
    }
    if (amenity == 'clinic' || healthcare == 'clinic' || healthcare == 'centre') {
      return NearbyCategory.clinic;
    }
    return NearbyCategory.doctor;
  }
}

/// Entité représentant un établissement de santé ou praticien à proximité
class NearbyPlace {
  final String id;
  final String osmType; // node, way, relation
  final String name;
  final NearbyCategory category;
  final String rawSpecialty;
  final String mappedSpecialty;
  final double latitude;
  final double longitude;
  final String address;
  final String phone;
  final String website;
  final String openingHours;
  final double distanceInMeters;

  const NearbyPlace({
    required this.id,
    required this.osmType,
    required this.name,
    required this.category,
    required this.rawSpecialty,
    required this.mappedSpecialty,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.phone,
    required this.website,
    required this.openingHours,
    required this.distanceInMeters,
  });

  LatLng get coordinates => LatLng(latitude, longitude);

  /// Distance formatée (ex: "450 m" ou "2.3 km")
  String get formattedDistance {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      final km = distanceInMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  NearbyPlace copyWith({
    String? id,
    String? osmType,
    String? name,
    NearbyCategory? category,
    String? rawSpecialty,
    String? mappedSpecialty,
    double? latitude,
    double? longitude,
    String? address,
    String? phone,
    String? website,
    String? openingHours,
    double? distanceInMeters,
  }) {
    return NearbyPlace(
      id: id ?? this.id,
      osmType: osmType ?? this.osmType,
      name: name ?? this.name,
      category: category ?? this.category,
      rawSpecialty: rawSpecialty ?? this.rawSpecialty,
      mappedSpecialty: mappedSpecialty ?? this.mappedSpecialty,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      openingHours: openingHours ?? this.openingHours,
      distanceInMeters: distanceInMeters ?? this.distanceInMeters,
    );
  }
}
