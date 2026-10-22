import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sahacare/core/constants/app_constants.dart';
import 'package:sahacare/core/theme/app_theme.dart';
import 'package:sahacare/features/appointments/domain/entities/doctor.dart';
import '../../domain/entities/orientation_recommendation.dart';
import '../../domain/entities/orientation_result.dart';

class OrientationResultView extends StatelessWidget {
  final OrientationResult result;
  final List<OrientationRecommendation> recommendations;
  final void Function(Doctor doctor) onBookAppointment;
  final void Function(String specialty) onAddDoctor;
  final void Function(String specialty) onSearchNearby;
  final VoidCallback onReset;
  final VoidCallback onViewHistory;

  const OrientationResultView({
    super.key,
    required this.result,
    required this.recommendations,
    required this.onBookAppointment,
    required this.onAddDoctor,
    required this.onSearchNearby,
    required this.onReset,
    required this.onViewHistory,
  });

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  IconData _getSpecialtyIcon(String specialty) {
    final lower = specialty.toLowerCase();
    if (lower.contains('cardio')) return Icons.favorite;
    if (lower.contains('derma')) return Icons.clean_hands;
    if (lower.contains('pediat')) return Icons.child_care;
    if (lower.contains('ophtal')) return Icons.visibility;
    if (lower.contains('dent')) return Icons.mood;
    if (lower.contains('gynec')) return Icons.pregnant_woman;
    if (lower.contains('neuro')) return Icons.psychology;
    if (lower.contains('ortho')) return Icons.accessibility_new;
    if (lower.contains('psych')) return Icons.self_improvement;
    if (lower.contains('orl')) return Icons.hearing;
    if (lower.contains('pneumo')) return Icons.air;
    if (lower.contains('gastro')) return Icons.restaurant;
    return Icons.medical_services;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode dégradé (si applicable)
        if (result.isDegradedMode) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off, size: 20, color: Colors.amber.shade900),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Mode hors-ligne : suggestion établie localement par mots-clés.",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Bandeau d'urgence
        _buildUrgencyBanner(result.urgency),
        const SizedBox(height: 16),

        // Liste des spécialités recommandées
        if (recommendations.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 36, color: Colors.grey.shade600),
                  const SizedBox(height: 12),
                  Text(
                    result.advice.isNotEmpty
                        ? result.advice
                        : "Aucune spécialité précise n'a pu être déterminée. Nous vous conseillons de consulter un médecin généraliste.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ],
              ),
            ),
          )
        else
          ...recommendations.map((rec) => _buildRecommendationCard(context, rec)),

        const SizedBox(height: 16),

        // Boîte de conseil général (sans médicament ni diagnostic)
        if (result.advice.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      "Conseil d'orientation",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  result.advice,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Boutons d'action en bas
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onViewHistory,
                icon: const Icon(Icons.history, size: 18),
                label: const Text("Historique"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("Nouvelle analyse"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUrgencyBanner(String urgency) {
    Color bg;
    Color border;
    Color textCol;
    IconData icon;
    String title;
    String desc;

    switch (urgency) {
      case 'emergency':
        bg = Colors.red.shade50;
        border = Colors.red.shade300;
        textCol = Colors.red.shade900;
        icon = Icons.error_outline;
        title = "Urgence médicale possible";
        desc =
            "Vos symptômes nécessitent une consultation très rapide ou un appel au ${AppConstants.emergencyPhoneName}.";
        break;
      case 'soon':
        bg = Colors.orange.shade50;
        border = Colors.orange.shade300;
        textCol = Colors.orange.shade900;
        icon = Icons.schedule;
        title = "À consulter prochainement";
        desc =
            "Il est recommandé de prendre rendez-vous sans trop tarder pour éviter une aggravation.";
        break;
      default:
        bg = Colors.teal.shade50;
        border = Colors.teal.shade200;
        textCol = Colors.teal.shade900;
        icon = Icons.check_circle_outline;
        title = "Consultation de routine";
        desc =
            "Prenez rendez-vous selon vos disponibilités habituelles.";
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: textCol),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textCol,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(fontSize: 13, color: textCol.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
      BuildContext context, OrientationRecommendation rec) {
    final spec = rec.specialty;
    final icon = _getSpecialtyIcon(spec.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entête Spécialité
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _buildConfidenceBadge(spec.confidence),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Raison de l'orientation
            if (spec.reason.isNotEmpty) ...[
              Text(
                spec.reason,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
            ],

            const Divider(height: 1),
            const SizedBox(height: 12),

            // Médecins du carnet correspondants
            if (rec.hasDoctorsInNotebook) ...[
              Row(
                children: [
                  Icon(Icons.people_alt_outlined,
                      size: 16, color: AppTheme.secondaryColor),
                  const SizedBox(width: 6),
                  Text(
                    "Médecins de votre carnet (${rec.notebookDoctors.length})",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...rec.notebookDoctors.map((doc) => _buildDoctorItem(doc)),
            ] else ...[
              // Aucun médecin de cette spécialité dans le carnet
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_off_outlined,
                            size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Aucun médecin de cette spécialité dans votre carnet.",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => onAddDoctor(spec.name),
                            icon: const Icon(Icons.person_add, size: 16),
                            label: const Text("Ajouter"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => onSearchNearby(spec.name),
                            icon: const Icon(Icons.near_me, size: 16),
                            label: const Text("À proximité"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorItem(Doctor doc) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (doc.hospitalOrClinic.isNotEmpty)
                      Text(
                        doc.hospitalOrClinic,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              if (doc.consultationFee > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${doc.consultationFee.toInt()} DT",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (doc.phone.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => _makePhoneCall(doc.phone),
                  icon: const Icon(Icons.phone, size: 16),
                  label: const Text("Appeler"),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onBookAppointment(doc),
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: const Text("Prendre RDV"),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(String confidence) {
    Color color;
    String label;
    switch (confidence.toLowerCase()) {
      case 'high':
        color = Colors.green.shade700;
        label = 'Indice de confiance : Élevé';
        break;
      case 'low':
        color = Colors.orange.shade700;
        label = 'Indice de confiance : Indicatif';
        break;
      default:
        color = AppTheme.secondaryColor;
        label = 'Indice de confiance : Modéré';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
