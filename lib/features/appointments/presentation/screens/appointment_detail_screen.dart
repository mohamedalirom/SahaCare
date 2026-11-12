import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/appointment.dart';
import '../controllers/appointments_controller.dart';
import '../widgets/appointment_status_badge.dart';

/// Écran affichant les détails d'un rendez-vous, avec options de modification, annulation et suppression
class AppointmentDetailScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  final Appointment? initialAppointment;

  const AppointmentDetailScreen({
    super.key,
    required this.appointmentId,
    this.initialAppointment,
  });

  @override
  ConsumerState<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  void _cancelAppointment(Appointment appointment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: Text(
          'Voulez-vous vraiment annuler votre consultation avec ${appointment.doctorName} prévue le ${AppUtils.formatDate(appointment.dateTime)} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non, garder'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(appointmentsNotifierProvider.notifier).cancelAppointment(appointment.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rendez-vous annulé avec succès.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text('Confirmer l\'annulation'),
          ),
        ],
      ),
    );
  }

  void _deleteAppointment(Appointment appointment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Supprimer définitivement'),
          ],
        ),
        content: Text(
          'Voulez-vous supprimer définitivement ce rendez-vous avec ${appointment.doctorName} de votre historique ?',
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
              await ref.read(appointmentsNotifierProvider.notifier).deleteAppointment(appointment.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rendez-vous supprimé avec succès.'),
                  backgroundColor: Colors.black87,
                ),
              );
              context.pop();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appointment = ref.watch(appointmentByIdProvider(widget.appointmentId)) ??
        widget.initialAppointment;

    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détail du Rendez-vous')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 60, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Rendez-vous introuvable ou supprimé'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Retour aux rendez-vous'),
              ),
            ],
          ),
        ),
      );
    }

    final isUpcoming = appointment.status == AppointmentStatus.upcoming;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail du Rendez-vous'),
        actions: [
          if (isUpcoming)
            IconButton(
              icon: const Icon(Icons.edit_calendar_rounded),
              tooltip: 'Modifier le rendez-vous',
              onPressed: () {
                context.push('/appointments/${appointment.id}/edit', extra: appointment);
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: 'Supprimer ce rendez-vous',
            onPressed: () => _deleteAppointment(appointment),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte Date & Statut
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUpcoming ? theme.colorScheme.primary.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppointmentStatusBadge(status: appointment.status),
                      Text(
                        '${appointment.fee.toInt()} DT',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isUpcoming ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUpcoming ? theme.colorScheme.primary : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppUtils.formatDate(appointment.dateTime),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Heure du rendez-vous : ${appointment.timeSlot}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isUpcoming ? theme.colorScheme.primary : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Praticien & Cabinet
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Praticien de Santé',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                        child: Text(
                          appointment.doctorName.replaceAll('Dr. ', '').substring(0, 1),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment.doctorName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              appointment.doctorSpecialty,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF0D9488),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          appointment.doctorAddress,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        appointment.doctorPhone,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Motif et Notes
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Motif de Consultation',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appointment.reason,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), height: 1.4),
                  ),
                  if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text(
                      'Notes personnelles & Consignes',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      appointment.notes!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Statut de Rappel / Alerte
            Container(
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
                      color: appointment.notificationEnabled
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      appointment.notificationEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                      color: appointment.notificationEnabled ? const Color(0xFFD97706) : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.notificationEnabled ? 'Rappel programmé' : 'Aucun rappel actif',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appointment.notificationEnabled ? appointment.reminder.label : 'Notifications désactivées pour ce RDV',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Boutons d'Action (Modifier / Annuler / Supprimer)
            if (isUpcoming) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/appointments/${appointment.id}/edit', extra: appointment);
                  },
                  icon: const Icon(Icons.edit_calendar_rounded),
                  label: const Text('Modifier la date ou l\'heure'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelAppointment(appointment),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Annuler ce rendez-vous'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _deleteAppointment(appointment),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Supprimer définitivement de l\'historique'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
