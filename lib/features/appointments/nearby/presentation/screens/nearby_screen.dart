import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/datasources/location_service.dart';
import '../../domain/entities/nearby_place.dart';
import '../controllers/nearby_controller.dart';
import '../widgets/nearby_detail_bottom_sheet.dart';
import '../widgets/nearby_place_card.dart';

/// Écran principal "Médecins et cliniques à proximité"
class NearbyScreen extends ConsumerStatefulWidget {
  final String? initialSpecialty;

  const NearbyScreen({super.key, this.initialSpecialty});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(nearbyControllerProvider.notifier).init();
      if (widget.initialSpecialty != null && widget.initialSpecialty!.isNotEmpty) {
        _searchController.text = widget.initialSpecialty!;
        ref.read(nearbyControllerProvider.notifier).setSelectedSpecialty(widget.initialSpecialty!);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(nearbyControllerProvider.notifier).setSearchQuery(val);
    });
  }

  void _centerOnUser() {
    final state = ref.read(nearbyControllerProvider);
    final pos = state.userPosition ?? LocationService.fallbackPosition;
    _mapController.move(LatLng(pos.latitude, pos.longitude), 14.5);
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _onPlaceTapped(NearbyPlace place) {
    ref.read(nearbyControllerProvider.notifier).selectPlace(place);
    _mapController.move(place.coordinates, 15.5);
    NearbyDetailBottomSheet.show(context, place);
  }

  Future<void> _savePlace(NearbyPlace place) async {
    try {
      final result = await ref
          .read(nearbyControllerProvider.notifier)
          .savePlaceToDoctorDirectory(place: place);

      if (!mounted) return;

      final message = result.wasDuplicate
          ? '${result.doctor.fullName} existe déjà dans votre carnet.'
          : '${result.doctor.fullName} a été enregistré dans votre carnet !';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Prendre RDV',
            textColor: Colors.white,
            onPressed: () {
              context.push('/appointments/book', extra: result.doctor);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'enregistrement : $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Color _getCategoryColor(NearbyCategory category) {
    switch (category) {
      case NearbyCategory.doctor:
        return const Color(0xFF0D9488);
      case NearbyCategory.clinic:
        return const Color(0xFF0284C7);
      case NearbyCategory.hospital:
        return const Color(0xFF4F46E5);
      case NearbyCategory.dentist:
        return const Color(0xFFEA580C);
      case NearbyCategory.pharmacy:
        return const Color(0xFF16A34A);
    }
  }

  IconData _getCategoryIcon(NearbyCategory category) {
    switch (category) {
      case NearbyCategory.doctor:
        return Icons.medical_services_rounded;
      case NearbyCategory.clinic:
        return Icons.local_hospital_rounded;
      case NearbyCategory.hospital:
        return Icons.apartment_rounded;
      case NearbyCategory.dentist:
        return Icons.mood_rounded;
      case NearbyCategory.pharmacy:
        return Icons.local_pharmacy_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nearbyControllerProvider);
    final userPos = state.userPosition ?? LocationService.fallbackPosition;
    final userLatLng = LatLng(userPos.latitude, userPos.longitude);

    // Écoute les erreurs pour recentrer la caméra quand la position change
    ref.listen<NearbyState>(nearbyControllerProvider, (previous, next) {
      if (previous?.userPosition != next.userPosition && next.userPosition != null) {
        _mapController.move(
          LatLng(next.userPosition!.latitude, next.userPosition!.longitude),
          14.0,
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // 1. CARTE OPENSTREETMAP PLEIN ÉCRAN
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLatLng,
              initialZoom: 14.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'tn.sahacare.app',
              ),
              MarkerLayer(
                markers: [
                  // Marqueur position utilisateur (point bleu pulsant)
                  Marker(
                    point: userLatLng,
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0284C7),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Marqueurs des établissements
                  for (final place in state.filteredPlaces)
                    Marker(
                      point: place.coordinates,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _onPlaceTapped(place),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(place.category),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: state.selectedPlace?.id == place.id
                                  ? Colors.yellowAccent
                                  : Colors.white,
                              width: state.selectedPlace?.id == place.id ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getCategoryIcon(place.category),
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. BARRE SUPÉRIEURE : Recherche & Filtres
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Champ de recherche avec bouton retour
                  Card(
                    elevation: 3,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => context.pop(),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              decoration: const InputDecoration(
                                hintText: 'Rechercher médecin, clinique, spécialité...',
                                hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(nearbyControllerProvider.notifier).setSearchQuery('');
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            tooltip: 'Actualiser',
                            onPressed: () {
                              ref
                                  .read(nearbyControllerProvider.notifier)
                                  .fetchPositionAndPlaces(forceRefresh: true);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Chips des catégories filtrables
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        for (final cat in NearbyCategory.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              avatar: Icon(
                                _getCategoryIcon(cat),
                                size: 14,
                                color: state.selectedCategories.contains(cat)
                                    ? Colors.white
                                    : _getCategoryColor(cat),
                              ),
                              label: Text(cat.labelFr),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: state.selectedCategories.contains(cat)
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                              selected: state.selectedCategories.contains(cat),
                              selectedColor: _getCategoryColor(cat),
                              backgroundColor: Colors.white.withValues(alpha: 0.95),
                              elevation: 2,
                              pressElevation: 4,
                              shadowColor: Colors.black12,
                              showCheckmark: false,
                              onSelected: (_) {
                                ref.read(nearbyControllerProvider.notifier).toggleCategory(cat);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Sélecteur de rayon (1, 3, 5, 10 km)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radar_rounded, size: 15, color: Color(0xFF0D9488)),
                          const SizedBox(width: 6),
                          const Text(
                            'Rayon : ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          for (final r in [1, 3, 5, 10]) ...[
                            GestureDetector(
                              onTap: () => ref.read(nearbyControllerProvider.notifier).setRadius(r),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: state.radiusKm == r ? const Color(0xFF0D9488) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${r}km',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: state.radiusKm == r ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. BOUTONS FLOTTANTS (Recentrer, Zoom)
          Positioned(
            right: 16,
            bottom: 220,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'btn_center_user',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D9488),
                  elevation: 3,
                  onPressed: _centerOnUser,
                  child: const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blueGrey.shade800,
                  elevation: 3,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 4),
                FloatingActionButton.small(
                  heroTag: 'btn_zoom_out',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blueGrey.shade800,
                  elevation: 3,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // 4. AVERTISSEMENT DISCRET OSM
          Positioned(
            left: 16,
            bottom: 190,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300, width: 0.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 12, color: Colors.blueGrey),
                  SizedBox(width: 4),
                  Text(
                    'Données OSM : vérifiez les informations auprès du lieu.',
                    style: TextStyle(fontSize: 10, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
          ),

          // 5. BANDEAU DE CHARGEMENT
          if (state.isLoading)
            Positioned(
              top: 170,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Recherche OpenStreetMap en cours...',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. GESTION DES ÉTATS D'ERREUR
          if (state.hasError)
            Positioned(
              top: 170,
              left: 20,
              right: 20,
              child: Card(
                elevation: 4,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.errorType == NearbyErrorType.gpsDisabled ||
                                state.errorType == NearbyErrorType.permissionDenied ||
                                state.errorType == NearbyErrorType.permissionDeniedPermanently
                            ? Icons.location_off_rounded
                            : Icons.wifi_off_rounded,
                        size: 36,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.errorMessage ?? 'Une erreur est survenue.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                            onPressed: () => ref.read(nearbyControllerProvider.notifier).loadFallbackPlaces(),
                            icon: const Icon(Icons.local_hospital_rounded, size: 16),
                            label: const Text('Afficher les praticiens de proximité'),
                          ),
                          if (state.errorType == NearbyErrorType.permissionDeniedPermanently)
                            FilledButton.tonal(
                              onPressed: () => ref.read(nearbyControllerProvider.notifier).openSettings(),
                              child: const Text('Ouvrir les paramètres'),
                            ),
                          if (state.errorType == NearbyErrorType.gpsDisabled)
                            FilledButton.tonal(
                              onPressed: () => ref.read(nearbyControllerProvider.notifier).openLocationSettings(),
                              child: const Text('Activer le GPS'),
                            ),
                          FilledButton(
                            onPressed: () => ref.read(nearbyControllerProvider.notifier).useFallbackPosition(),
                            child: const Text('Position par défaut (Sousse)'),
                          ),
                          OutlinedButton(
                            onPressed: () => ref
                                .read(nearbyControllerProvider.notifier)
                                .fetchPositionAndPlaces(forceRefresh: true),
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 7. FEUILLE COULISSANTE (DraggableScrollableSheet) AVEC LA LISTE DES RÉSULTATS
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.28,
            minChildSize: 0.12,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.12, 0.28, 0.6, 0.85],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    // Handle de drag
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // En-tête de la liste
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Établissements trouvés (${state.filteredPlaces.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Rayon ${state.radiusKm} km',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // État vide
                    if (state.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'Aucun établissement dans ce rayon (${state.radiusKm} km).',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  ref.read(nearbyControllerProvider.notifier).setRadius(10);
                                },
                                icon: const Icon(Icons.zoom_out_map_rounded, size: 16),
                                label: const Text('Élargir à 10 km'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      for (final place in state.filteredPlaces)
                        NearbyPlaceCard(
                          place: place,
                          onTap: () => _onPlaceTapped(place),
                          onSaveTap: () => _savePlace(place),
                        ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
