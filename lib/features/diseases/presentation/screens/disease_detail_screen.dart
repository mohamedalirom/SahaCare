import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/disease.dart';
import '../widgets/disease_status_badge.dart';

/// Écran affichant les détails complets d'une maladie / affection
class DiseaseDetailScreen extends StatelessWidget {
  final String diseaseId;
  final Disease? initialDisease;

  const DiseaseDetailScreen({
    super.key,
    required this.diseaseId,
    this.initialDisease,
  });

  @override
  Widget build(BuildContext context) {
    // Récupère l'objet ou utilise la démo correspondante
    final disease = initialDisease ??
        Disease.mockDiseases.firstWhere(
          (d) => d.id == diseaseId,
          orElse: () => Disease.mockDiseases.first,
        );

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de l\'Affection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: () {
              context.push('/diseases/${disease.id}/edit', extra: disease);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: 'Supprimer',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Supprimer cette affection ?'),
                  content: Text(
                    'Êtes-vous sûr de vouloir retirer "${disease.name}" de votre carnet médical ?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx); // Ferme la modal
                        context.pop(); // Retourne à la liste
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Affection "${disease.name}" supprimée.')),
                        );
                      },
                      child: const Text('Supprimer'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte d'en-tête
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          disease.category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      DiseaseStatusBadge(status: disease.status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    disease.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      DiseaseSeverityBadge(severity: disease.severity),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Diagnostiqué le ${AppUtils.formatDate(disease.diagnosedDate)}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Médecin traitant
            _buildInfoCard(
              context: context,
              icon: Icons.person_pin_rounded,
              title: 'Médecin / Praticien Référent',
              content: disease.treatingDoctor,
            ),
            const SizedBox(height: 16),

            // Description médicale
            _buildSectionCard(
              context: context,
              icon: Icons.description_outlined,
              title: 'Description & Diagnostic',
              child: Text(
                disease.description,
                style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF334155)),
              ),
            ),
            const SizedBox(height: 16),

            // Symptômes
            if (disease.symptoms.isNotEmpty) ...[
              _buildSectionCard(
                context: context,
                icon: Icons.healing_outlined,
                title: 'Symptômes Notifiés',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: disease.symptoms
                      .map(
                        (symptom) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            symptom,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Traitements
            if (disease.treatments.isNotEmpty) ...[
              _buildSectionCard(
                context: context,
                icon: Icons.medication_outlined,
                title: 'Traitements & Prescriptions Actuels',
                child: Column(
                  children: disease.treatments
                      .map(
                        (treatment) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  treatment,
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Notes complémentaires
            if (disease.notes != null && disease.notes!.isNotEmpty) ...[
              _buildSectionCard(
                context: context,
                icon: Icons.edit_note_rounded,
                title: 'Notes Médicales & Recommandations',
                child: Text(
                  disease.notes!,
                  style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Bouton Modifier en bas
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/diseases/${disease.id}/edit', extra: disease);
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Modifier cette affection'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
