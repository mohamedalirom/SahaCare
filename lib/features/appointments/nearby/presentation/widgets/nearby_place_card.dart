import 'package:flutter/material.dart';
import '../../domain/entities/nearby_place.dart';

/// Carte représentant un praticien ou établissement dans la liste coulissante
class NearbyPlaceCard extends StatelessWidget {
  final NearbyPlace place;
  final VoidCallback onTap;
  final VoidCallback onSaveTap;

  const NearbyPlaceCard({
    super.key,
    required this.place,
    required this.onTap,
    required this.onSaveTap,
  });

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
    final color = _getCategoryColor(place.category);
    final icon = _getCategoryIcon(place.category);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pastille d'icône colorée
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),

            // Contenu texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Distance
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          place.formattedDistance,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Catégorie et spécialité
                  Row(
                    children: [
                      Text(
                        place.category.labelFr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      if (place.mappedSpecialty.isNotEmpty) ...[
                        Text(
                          ' • ${place.mappedSpecialty}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Adresse abrégée
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bouton enregistrer rapide
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined, size: 20),
              color: const Color(0xFF0D9488),
              tooltip: 'Enregistrer dans mon carnet',
              onPressed: onSaveTap,
            ),
          ],
        ),
      ),
    );
  }
}
