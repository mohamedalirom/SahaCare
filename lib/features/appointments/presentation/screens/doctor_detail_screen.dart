import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/doctor.dart';
import '../controllers/appointments_controller.dart';
import '../widgets/add_edit_doctor_dialog.dart';

/// Fiche détaillée d'un médecin avec options de modification et suppression
class DoctorDetailScreen extends ConsumerWidget {
  final String doctorId;
  final Doctor? initialDoctor;

  const DoctorDetailScreen({
    super.key,
    required this.doctorId,
    this.initialDoctor,
  });

  void _confirmDelete(BuildContext context, WidgetRef ref, Doctor doctor) async {
    final notifier = ref.read(appointmentsNotifierProvider.notifier);
    final hasAppointments = await notifier.doctorHasAppointments(doctor.id);

    if (!context.mounted) return;

    if (hasAppointments) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Suppression impossible'),
            ],
          ),
          content: Text(
            'Impossible de supprimer ${doctor.fullName} car des rendez-vous lui sont actuellement associés dans votre carnet.\n\nVeuillez d\'abord annuler ou supprimer ses rendez-vous.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Supprimer ce médecin ?'),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment retirer ${doctor.fullName} de votre annuaire de praticiens ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await notifier.deleteDoctor(doctor.id);
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${doctor.fullName} supprimé de l\'annuaire.'),
                    backgroundColor: Colors.black87,
                  ),
                );
                context.pop();
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final doctor = ref.watch(doctorByIdProvider(doctorId)) ?? initialDoctor;

    if (doctor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil du Médecin')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_outlined, size: 60, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Médecin introuvable ou supprimé'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Retour à l\'annuaire'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil du Médecin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier les informations du médecin',
            onPressed: () {
              AddEditDoctorDialog.show(context, doctor: doctor);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: 'Supprimer ce médecin',
            onPressed: () => _confirmDelete(context, ref, doctor),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte En-tête Médecin
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_pin_rounded, size: 48, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    doctor.fullName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctor.specialty,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        '${doctor.rating}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${doctor.reviewsCount} avis)',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tarifs et Coordonnées
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.payments_outlined,
                    iconColor: Colors.green,
                    title: 'Tarif consultation',
                    value: '${doctor.consultationFee.toInt()} DT',
                  ),
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),
                  _buildDetailRow(
                    icon: Icons.location_on_outlined,
                    iconColor: theme.colorScheme.secondary,
                    title: 'Adresse / Cabinet',
                    value: '${doctor.hospitalOrClinic}\n${doctor.address}',
                  ),
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),
                  _buildDetailRow(
                    icon: Icons.phone_outlined,
                    iconColor: theme.colorScheme.primary,
                    title: 'Téléphone direct',
                    value: doctor.phone,
                  ),
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),
                  _buildDetailRow(
                    icon: Icons.email_outlined,
                    iconColor: const Color(0xFF0284C7),
                    title: 'E-mail professionnel',
                    value: doctor.email,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Biographie / Présentation
            Container(
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
                  const Row(
                    children: [
                      Icon(Icons.badge_outlined, size: 20, color: Color(0xFF0F172A)),
                      SizedBox(width: 8),
                      Text(
                        'Présentation & Expertise',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    doctor.bio,
                    style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Disponibilités
            Container(
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
                  const Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF0F172A)),
                      SizedBox(width: 8),
                      Text(
                        'Jours de consultation',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: doctor.availableDays
                        .map(
                          (day) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              day,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bouton Prendre Rendez-vous
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/appointments/book', extra: doctor);
                },
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Prendre un rendez-vous avec ce médecin'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
