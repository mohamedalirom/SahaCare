import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/appointment.dart';
import '../widgets/appointment_status_badge.dart';

/// Écran affichant les détails d'un rendez-vous, avec options de modification et d'annulation
class AppointmentDetailScreen extends StatefulWidget {
  final String appointmentId;
  final Appointment? initialAppointment;

  const AppointmentDetailScreen({
    super.key,
    required this.appointmentId,
    this.initialAppointment,
  });

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late Appointment _appointment;

  @override
  void initState() {
    super.initState();
    _appointment = widget.initialAppointment ??
        Appointment.mockAppointments.firstWhere(
          (a) => a.id == widget.appointmentId,
          orElse: () => Appointment.mockAppointments.first,
        );
  }

  void _cancelAppointment() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: Text(
          'Voulez-vous vraiment annuler votre consultation avec ${_appointment.doctorName} prévue le ${AppUtils.formatDate(_appointment.dateTime)} ?',
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
            onPressed: () {
              setState(() {
                _appointment = Appointment(
                  id: _appointment.id,
                  doctorId: _appointment.doctorId,
                  doctorName: _appointment.doctorName,
                  doctorSpecialty: _appointment.doctorSpecialty,
                  doctorAddress: _appointment.doctorAddress,
                  doctorPhone: _appointment.doctorPhone,
                  dateTime: _appointment.dateTime,
                  timeSlot: _appointment.timeSlot,
                  reason: _appointment.reason,
                  status: AppointmentStatus.cancelled,
                  reminder: ReminderOption.none,
                  notificationEnabled: false,
                  notes: _appointment.notes,
                  fee: _appointment.fee,
                );
              });
              Navigator.pop(ctx);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUpcoming = _appointment.status == AppointmentStatus.upcoming;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail du Rendez-vous'),
        actions: [
          if (isUpcoming)
            IconButton(
              icon: const Icon(Icons.edit_calendar_rounded),
              tooltip: 'Modifier le rendez-vous',
              onPressed: () {
                context.push('/appointments/${_appointment.id}/edit', extra: _appointment);
              },
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
                      AppointmentStatusBadge(status: _appointment.status),
                      Text(
                        '${_appointment.fee.toInt()} DT',
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
                      color: isUpcoming
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              AppUtils.formatDate(_appointment.dateTime),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Text('Date', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                        Container(height: 40, width: 1, color: const Color(0xFFCBD5E1)),
                        Column(
                          children: [
                            Icon(Icons.access_time_filled_rounded, color: theme.colorScheme.secondary, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              _appointment.timeSlot,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Text('Heure', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Carte Médecin
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
                  const Text(
                    'Informations sur le Praticien',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.person_pin_rounded, color: theme.colorScheme.primary, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _appointment.doctorName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              _appointment.doctorSpecialty,
                              style: TextStyle(color: theme.colorScheme.secondary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _appointment.doctorAddress,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        _appointment.doctorPhone,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Motif de consultation
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
                  const Text(
                    'Motif de Consultation',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _appointment.reason,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
                  ),
                  if (_appointment.notes != null && _appointment.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Notes personnelles :',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _appointment.notes!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section Notification & Rappel (Exigence Dali)
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
                      color: _appointment.notificationEnabled
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _appointment.notificationEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                      color: _appointment.notificationEnabled ? const Color(0xFFD97706) : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _appointment.notificationEnabled ? 'Rappel programmé' : 'Aucun rappel actif',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _appointment.notificationEnabled ? _appointment.reminder.label : 'Notifications désactivées pour ce RDV',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Boutons d'Action (Modifier / Annuler)
            if (isUpcoming) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/appointments/${_appointment.id}/edit', extra: _appointment);
                  },
                  icon: const Icon(Icons.edit_calendar_rounded),
                  label: const Text('Modifier la date ou l\'heure'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelAppointment,
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
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
