/// Utilitaire de correspondance entre les tags OpenStreetMap et les spécialités médicales de SahaCare
class SpecialtyMapper {
  SpecialtyMapper._();

  /// Correspondance simple en mémoire des tags OSM (healthcare:speciality, amenity, etc.)
  /// vers les spécialités SahaCare.
  static const Map<String, String> _osmToSahaCare = {
    // Cardiologie
    'cardiology': 'Cardiologie',
    'cardiologist': 'Cardiologie',
    'cardio': 'Cardiologie',

    // Dermatologie
    'dermatology': 'Dermatologie',
    'dermatologist': 'Dermatologie',

    // Pédiatrie
    'paediatrics': 'Pédiatrie',
    'pediatrics': 'Pédiatrie',
    'paediatrician': 'Pédiatrie',
    'pediatrician': 'Pédiatrie',

    // Médecine générale
    'general': 'Médecine Générale',
    'general_practitioner': 'Médecine Générale',
    'general_practice': 'Médecine Générale',
    'gp': 'Médecine Générale',
    'family_medicine': 'Médecine Générale',
    'community': 'Médecine Générale',

    // Dentiste
    'dentist': 'Dentiste',
    'dentistry': 'Dentiste',
    'orthodontics': 'Dentiste',

    // Ophtalmologie
    'ophthalmology': 'Ophtalmologie',
    'ophthalmologist': 'Ophtalmologie',
    'ophtalmo': 'Ophtalmologie',

    // Gynécologie & Obstétrique
    'gynaecology': 'Gynécologie',
    'gynecology': 'Gynécologie',
    'obstetrics': 'Gynécologie',
    'obstetrics_gynecology': 'Gynécologie',

    // Neurologie
    'neurology': 'Neurologie',
    'neurologist': 'Neurologie',

    // Orthopédie
    'orthopaedics': 'Orthopédie',
    'orthopedics': 'Orthopédie',
    'orthopaedic_surgery': 'Orthopédie',

    // Psychiatrie
    'psychiatry': 'Psychiatrie',
    'psychiatrist': 'Psychiatrie',
    'psychology': 'Psychiatrie',
  };

  /// Mappe une valeur brute OSM vers une spécialité SahaCare
  static String mapSpecialty(String? rawSpecialty, {String? amenity}) {
    if (rawSpecialty != null && rawSpecialty.trim().isNotEmpty) {
      final normalized = rawSpecialty.trim().toLowerCase().replaceAll(RegExp(r'[\-_]'), '_');
      for (final entry in _osmToSahaCare.entries) {
        if (normalized.contains(entry.key)) {
          return entry.value;
        }
      }
    }

    if (amenity != null) {
      final normalizedAmenity = amenity.trim().toLowerCase();
      if (normalizedAmenity == 'dentist') return 'Dentiste';
      if (normalizedAmenity == 'pharmacy') return 'Pharmacie';
    }

    return '';
  }
}
