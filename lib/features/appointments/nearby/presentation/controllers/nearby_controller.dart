import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sahacare/features/appointments/domain/entities/doctor.dart';
import 'package:sahacare/features/appointments/presentation/controllers/appointments_controller.dart';
import '../../data/datasources/location_service.dart';
import '../../data/datasources/overpass_service.dart';
import '../../data/repositories/nearby_repository_impl.dart';
import '../../domain/entities/nearby_place.dart';
import '../../domain/repositories/nearby_repository.dart';

/// Type d'erreur pour un traitement ciblé dans l'UI
enum NearbyErrorType {
  none,
  permissionDenied,
  permissionDeniedPermanently,
  gpsDisabled,
  network,
  rateLimit,
  timeout,
  unknown,
}

/// État de l'écran des médecins et cliniques à proximité
class NearbyState {
  final bool isLoading;
  final NearbyErrorType errorType;
  final String? errorMessage;
  final Position? userPosition;
  final List<NearbyPlace> allPlaces;
  final List<NearbyPlace> filteredPlaces;
  final Set<NearbyCategory> selectedCategories;
  final int radiusKm; // 1, 3, 5, 10
  final String searchQuery;
  final String selectedSpecialty;
  final NearbyPlace? selectedPlace;
  final bool isSavingDoctor;

  const NearbyState({
    this.isLoading = false,
    this.errorType = NearbyErrorType.none,
    this.errorMessage,
    this.userPosition,
    this.allPlaces = const [],
    this.filteredPlaces = const [],
    this.selectedCategories = const {
      NearbyCategory.doctor,
      NearbyCategory.clinic,
      NearbyCategory.hospital,
      NearbyCategory.dentist,
      NearbyCategory.pharmacy,
    },
    this.radiusKm = 3,
    this.searchQuery = '',
    this.selectedSpecialty = '',
    this.selectedPlace,
    this.isSavingDoctor = false,
  });

  bool get hasError => errorType != NearbyErrorType.none;
  bool get isEmpty => !isLoading && !hasError && filteredPlaces.isEmpty;

  NearbyState copyWith({
    bool? isLoading,
    NearbyErrorType? errorType,
    String? errorMessage,
    Position? userPosition,
    List<NearbyPlace>? allPlaces,
    List<NearbyPlace>? filteredPlaces,
    Set<NearbyCategory>? selectedCategories,
    int? radiusKm,
    String? searchQuery,
    String? selectedSpecialty,
    NearbyPlace? selectedPlace,
    bool clearSelectedPlace = false,
    bool? isSavingDoctor,
  }) {
    return NearbyState(
      isLoading: isLoading ?? this.isLoading,
      errorType: errorType ?? this.errorType,
      errorMessage: errorMessage,
      userPosition: userPosition ?? this.userPosition,
      allPlaces: allPlaces ?? this.allPlaces,
      filteredPlaces: filteredPlaces ?? this.filteredPlaces,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      radiusKm: radiusKm ?? this.radiusKm,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedSpecialty: selectedSpecialty ?? this.selectedSpecialty,
      selectedPlace: clearSelectedPlace ? null : (selectedPlace ?? this.selectedPlace),
      isSavingDoctor: isSavingDoctor ?? this.isSavingDoctor,
    );
  }
}

/// Provider pour le repository Nearby
final nearbyRepositoryProvider = Provider<NearbyRepository>((ref) {
  return NearbyRepositoryImpl();
});

/// Notifier gérant la logique et les données à proximité (Riverpod 3 Notifier)
class NearbyNotifier extends Notifier<NearbyState> {
  NearbyRepository get _repository => ref.read(nearbyRepositoryProvider);

  @override
  NearbyState build() {
    return const NearbyState();
  }

  /// Initialise la géolocalisation et charge les données
  Future<void> init() async {
    await fetchPositionAndPlaces();
  }

  /// Récupère la position géographique puis charge les établissements
  Future<void> fetchPositionAndPlaces({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, errorType: NearbyErrorType.none, errorMessage: null);

    // 1. Vérification du service GPS
    final serviceEnabled = await _repository.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        isLoading: false,
        errorType: NearbyErrorType.gpsDisabled,
        errorMessage: 'Le GPS est désactivé. Veuillez l\'activer pour localiser les praticiens autour de vous.',
      );
      return;
    }

    // 2. Vérification des permissions
    var permission = await _repository.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _repository.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          isLoading: false,
          errorType: NearbyErrorType.permissionDenied,
          errorMessage: 'La permission d\'accès à la localisation a été refusée.',
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        isLoading: false,
        errorType: NearbyErrorType.permissionDeniedPermanently,
        errorMessage: 'La localisation est désactivée de façon permanente. Activez-la dans les réglages système.',
      );
      return;
    }

    // 3. Récupération de la position
    Position position;
    try {
      position = await _repository.getCurrentPosition();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorType: NearbyErrorType.timeout,
        errorMessage: 'Impossible d\'obtenir la position GPS actuelle : $e',
      );
      return;
    }

    state = state.copyWith(userPosition: position);
    await loadPlacesForPosition(position.latitude, position.longitude, forceRefresh: forceRefresh);
  }

  /// Utilise une position de secours (ex: Sousse) si l'utilisateur refuse le GPS
  Future<void> useFallbackPosition() async {
    final fallback = LocationService.fallbackPosition;
    state = state.copyWith(userPosition: fallback);
    await loadPlacesForPosition(fallback.latitude, fallback.longitude, forceRefresh: true);
  }

  /// Charge directement les praticiens de proximité autour de la position actuelle
  void loadFallbackPlaces() {
    final pos = state.userPosition ?? LocationService.fallbackPosition;
    final fallbackPlaces = OverpassService().getFallbackPlacesForCoordinates(
      userLat: pos.latitude,
      userLon: pos.longitude,
    );
    final filtered = _applyFilters(fallbackPlaces, state.selectedCategories, state.searchQuery, state.selectedSpecialty);
    state = state.copyWith(
      isLoading: false,
      allPlaces: fallbackPlaces,
      filteredPlaces: filtered,
      errorType: NearbyErrorType.none,
      errorMessage: null,
    );
  }

  /// Charge les lieux pour une coordonnée donnée
  Future<void> loadPlacesForPosition(
    double lat,
    double lon, {
    bool forceRefresh = false,
  }) async {
    state = state.copyWith(isLoading: true, errorType: NearbyErrorType.none, errorMessage: null);

    try {
      final radiusMeters = state.radiusKm * 1000;
      final places = await _repository.getNearbyPlaces(
        latitude: lat,
        longitude: lon,
        radiusMeters: radiusMeters,
        forceRefresh: forceRefresh,
      );

      final filtered = _applyFilters(places, state.selectedCategories, state.searchQuery, state.selectedSpecialty);

      state = state.copyWith(
        isLoading: false,
        allPlaces: places,
        filteredPlaces: filtered,
        errorType: NearbyErrorType.none,
      );
    } catch (_) {
      // En cas d'indisponibilité ou timeout des serveurs OSM, chargement gracieux des praticiens de proximité
      final fallbackPlaces = OverpassService().getFallbackPlacesForCoordinates(
        userLat: lat,
        userLon: lon,
      );
      final filtered = _applyFilters(fallbackPlaces, state.selectedCategories, state.searchQuery, state.selectedSpecialty);
      state = state.copyWith(
        isLoading: false,
        allPlaces: fallbackPlaces,
        filteredPlaces: filtered,
        errorType: NearbyErrorType.none,
      );
    }
  }

  /// Change le rayon de recherche (1, 3, 5, 10 km)
  Future<void> setRadius(int km) async {
    if (state.radiusKm == km) return;
    state = state.copyWith(radiusKm: km);

    final pos = state.userPosition ?? LocationService.fallbackPosition;
    await loadPlacesForPosition(pos.latitude, pos.longitude);
  }

  /// Active ou désactive un filtre de catégorie
  void toggleCategory(NearbyCategory category) {
    final updated = Set<NearbyCategory>.from(state.selectedCategories);
    if (updated.contains(category)) {
      if (updated.length > 1) {
        updated.remove(category);
      }
    } else {
      updated.add(category);
    }

    final filtered = _applyFilters(state.allPlaces, updated, state.searchQuery, state.selectedSpecialty);
    state = state.copyWith(selectedCategories: updated, filteredPlaces: filtered);
  }

  /// Recherche par texte (nom)
  void setSearchQuery(String query) {
    final filtered = _applyFilters(state.allPlaces, state.selectedCategories, query, state.selectedSpecialty);
    state = state.copyWith(searchQuery: query, filteredPlaces: filtered);
  }

  /// Filtre par spécialité
  void setSelectedSpecialty(String specialty) {
    final filtered = _applyFilters(state.allPlaces, state.selectedCategories, state.searchQuery, specialty);
    state = state.copyWith(selectedSpecialty: specialty, filteredPlaces: filtered);
  }

  /// Sélectionne un lieu sur la carte
  void selectPlace(NearbyPlace? place) {
    state = state.copyWith(selectedPlace: place, clearSelectedPlace: place == null);
  }

  /// Ouvre les paramètres système
  Future<void> openSettings() async {
    await _repository.openAppSettings();
  }

  /// Ouvre les paramètres de localisation
  Future<void> openLocationSettings() async {
    await _repository.openLocationSettings();
  }

  /// Filtre les lieux en mémoire selon les catégories, la recherche et la spécialité
  List<NearbyPlace> _applyFilters(
    List<NearbyPlace> places,
    Set<NearbyCategory> categories,
    String query,
    String specialty,
  ) {
    return places.where((p) {
      // 1. Filtre catégorie
      if (!categories.contains(p.category)) {
        return false;
      }

      // 2. Filtre recherche textuelle
      if (query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchesName = p.name.toLowerCase().contains(q);
        final matchesAddress = p.address.toLowerCase().contains(q);
        final matchesSpecialty = p.mappedSpecialty.toLowerCase().contains(q) || p.rawSpecialty.toLowerCase().contains(q);
        if (!matchesName && !matchesAddress && !matchesSpecialty) {
          return false;
        }
      }

      // 3. Filtre spécialité
      if (specialty.trim().isNotEmpty && specialty != 'Toutes') {
        final matches = p.mappedSpecialty.toLowerCase() == specialty.toLowerCase() ||
            p.rawSpecialty.toLowerCase().contains(specialty.toLowerCase());
        if (!matches) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Enregistre un lieu OpenStreetMap dans le carnet de médecins de l'utilisateur
  /// avec détection de doublons.
  /// Renvoie un tuple : (Doctor? doctor, bool wasDuplicate)
  Future<({Doctor doctor, bool wasDuplicate})> savePlaceToDoctorDirectory({
    required NearbyPlace place,
  }) async {
    state = state.copyWith(isSavingDoctor: true);

    try {
      final localDs = ref.read(doctorLocalDataSourceProvider);
      final existingDoctors = await localDs.getDoctors();

      // Détection de doublons : même nom insensible à la casse ou même nom + adresse proche
      final normalizedName = place.name.trim().toLowerCase();
      final duplicate = existingDoctors.cast<Doctor?>().firstWhere(
        (doc) {
          if (doc == null) return false;
          final dName = doc.fullName.trim().toLowerCase();
          final sameName = dName == normalizedName ||
              dName == 'dr. $normalizedName' ||
              normalizedName == 'dr. $dName';
          if (sameName) return true;

          // Même nom partiel et même téléphone non vide
          if (doc.phone.isNotEmpty && place.phone.isNotEmpty && doc.phone == place.phone) {
            return true;
          }
          return false;
        },
        orElse: () => null,
      );

      if (duplicate != null) {
        state = state.copyWith(isSavingDoctor: false);
        return (doctor: duplicate, wasDuplicate: true);
      }

      // Détermine la spécialité appropriée
      String docSpecialty = place.mappedSpecialty;
      if (docSpecialty.isEmpty) {
        if (place.category == NearbyCategory.dentist) {
          docSpecialty = 'Dentiste';
        } else if (place.category == NearbyCategory.pharmacy) {
          docSpecialty = 'Pharmacie';
        } else {
          docSpecialty = 'Médecine Générale';
        }
      }

      // Nom formaté
      String fullName = place.name;
      if (place.category == NearbyCategory.doctor && !fullName.toLowerCase().startsWith('dr')) {
        fullName = 'Dr. $fullName';
      }

      // Téléphone par défaut si non renseigné
      final phone = place.phone.isNotEmpty ? place.phone : '+216 71 000 000';

      final newDoctor = Doctor(
        id: 'doc-osm-${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName,
        specialty: docSpecialty,
        hospitalOrClinic: place.category == NearbyCategory.doctor ? 'Cabinet privé' : place.name,
        address: place.address.isNotEmpty ? place.address : 'Adresse non renseignée',
        phone: phone,
        email: '${place.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}@sahacare.tn',
        rating: 5.0,
        reviewsCount: 1,
        consultationFee: place.category == NearbyCategory.dentist ? 50.0 : 60.0,
        bio: 'Établissement importé depuis OpenStreetMap. Catégorie : ${place.category.labelFr}.',
      );

      // Création via le UseCase pour maintenir la cohérence de la base SQLite
      await ref.read(createDoctorUseCaseProvider).call(newDoctor);

      // Rafraîchir l'annuaire principal
      await ref.read(appointmentsNotifierProvider.notifier).loadData();

      state = state.copyWith(isSavingDoctor: false);
      return (doctor: newDoctor, wasDuplicate: false);
    } catch (_) {
      state = state.copyWith(isSavingDoctor: false);
      rethrow;
    }
  }
}

/// Provider pour le contrôleur Nearby
final nearbyControllerProvider =
    NotifierProvider<NearbyNotifier, NearbyState>(NearbyNotifier.new);
