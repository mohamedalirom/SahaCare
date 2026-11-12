import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/nearby_place.dart';
import '../controllers/nearby_controller.dart';

/// Fiche détaillée d'un établissement ou praticien sélectionné
class NearbyDetailBottomSheet extends ConsumerWidget {
  final NearbyPlace place;

  const NearbyDetailBottomSheet({super.key, required this.place});

  static Future<void> show(BuildContext context, NearbyPlace place) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NearbyDetailBottomSheet(place: place),
    );
  }

  Color _getCategoryColor(NearbyCategory category) {
    switch (category) {
      case NearbyCategory.doctor:
        return const Color(0xFF0D9488); // Teal
      case NearbyCategory.clinic:
        return const Color(0xFF0284C7); // Sky Blue
      case NearbyCategory.hospital:
        return const Color(0xFF4F46E5); // Indigo
      case NearbyCategory.dentist:
        return const Color(0xFFEA580C); // Orange
      case NearbyCategory.pharmacy:
        return const Color(0xFF16A34A); // Green
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

  Future<void> _makePhoneCall(BuildContext context, String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir l\'application téléphone.')),
        );
      }
    }
  }

  Future<void> _openDirections(double lat, double lon) async {
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWebsite(BuildContext context, String url) async {
    var fixedUrl = url.trim();
    if (!fixedUrl.startsWith('http://') && !fixedUrl.startsWith('https://')) {
      fixedUrl = 'https://$fixedUrl';
    }
    final uri = Uri.tryParse(fixedUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir l\'adresse web spécifiée.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryColor = _getCategoryColor(place.category);
    final categoryIcon = _getCategoryIcon(place.category);
    final isSaving = ref.watch(nearbyControllerProvider).isSavingDoctor;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // En-tête : Badge catégorie et distance
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(categoryIcon, size: 14, color: categoryColor),
                    const SizedBox(width: 6),
                    Text(
                      place.category.labelFr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_walk_rounded, size: 14, color: Colors.blueGrey.shade700),
                    const SizedBox(width: 4),
                    Text(
                      place.formattedDistance,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Nom de l'établissement
          Text(
            place.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),

          // Spécialité si disponible
          if (place.mappedSpecialty.isNotEmpty || place.rawSpecialty.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.verified_user_rounded, size: 15, color: Color(0xFF0D9488)),
                const SizedBox(width: 6),
                Text(
                  place.mappedSpecialty.isNotEmpty ? place.mappedSpecialty : place.rawSpecialty,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D9488),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Informations détaillées
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.location_on_outlined,
                  title: 'Adresse',
                  value: place.address,
                ),
                if (place.phone.isNotEmpty) ...[
                  const Divider(height: 16, thickness: 0.5),
                  _buildInfoRow(
                    icon: Icons.phone_outlined,
                    title: 'Téléphone',
                    value: place.phone,
                  ),
                ],
                if (place.openingHours.isNotEmpty) ...[
                  const Divider(height: 16, thickness: 0.5),
                  _buildInfoRow(
                    icon: Icons.schedule_rounded,
                    title: 'Horaires',
                    value: place.openingHours,
                  ),
                ],
                if (place.website.isNotEmpty) ...[
                  const Divider(height: 16, thickness: 0.5),
                  _buildInfoRow(
                    icon: Icons.language_rounded,
                    title: 'Site Web',
                    value: place.website,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Boutons d'action rapides (Appeler, Itinéraire, Site)
          Row(
            children: [
              if (place.phone.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _makePhoneCall(context, place.phone),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Appeler'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openDirections(place.latitude, place.longitude),
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Itinéraire'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (place.website.isNotEmpty) ...[
                const SizedBox(width: 10),
                IconButton.outlined(
                  onPressed: () => _openWebsite(context, place.website),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  tooltip: 'Site web',
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Bouton principal : Enregistrer dans mon carnet
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      try {
                        final result = await ref
                            .read(nearbyControllerProvider.notifier)
                            .savePlaceToDoctorDirectory(place: place);

                        if (!context.mounted) return;
                        Navigator.of(context).pop();

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
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erreur lors de l\'enregistrement : $e'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    },
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.bookmark_add_rounded, size: 20),
              label: Text(isSaving ? 'Enregistrement...' : 'Enregistrer dans mon carnet'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
