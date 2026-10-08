import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/appointment.dart';

/// Écran de modification d'un rendez-vous existant
class EditAppointmentScreen extends StatefulWidget {
  final String appointmentId;
  final Appointment? initialAppointment;

  const EditAppointmentScreen({
    super.key,
    required this.appointmentId,
    this.initialAppointment,
  });

  @override
  State<EditAppointmentScreen> createState() => _EditAppointmentScreenState();
}

class _EditAppointmentScreenState extends State<EditAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();

  late Appointment _appointment;
  late DateTime _selectedDate;
  late String _selectedSlot;
  late TextEditingController _reasonController;
  late TextEditingController _notesController;
  late bool _enableNotification;
  late ReminderOption _selectedReminder;

  final List<String> _morningSlots = ['09:00', '09:30', '10:00', '10:30', '11:00', '11:30'];
  final List<String> _afternoonSlots = ['14:00', '14:30', '15:00', '15:30', '16:00', '16:30'];

  @override
  void initState() {
    super.initState();
    _appointment = widget.initialAppointment ??
        Appointment.mockAppointments.firstWhere(
          (a) => a.id == widget.appointmentId,
          orElse: () => Appointment.mockAppointments.first,
        );

    _selectedDate = _appointment.dateTime;
    _selectedSlot = _appointment.timeSlot;
    _reasonController = TextEditingController(text: _appointment.reason);
    _notesController = TextEditingController(text: _appointment.notes ?? '');
    _enableNotification = _appointment.notificationEnabled;
    _selectedReminder = _appointment.reminder;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rendez-vous avec ${_appointment.doctorName} reporté au ${AppUtils.formatDate(_selectedDate)} à $_selectedSlot.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le Rendez-vous'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Rappel du Médecin
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_pin_rounded, color: theme.colorScheme.primary, size: 32),
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
            ),
            const SizedBox(height: 20),

            // Date
            const Text(
              'Nouvelle Date de Consultation',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          AppUtils.formatDate(_selectedDate),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      'Changer',
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Créneaux horaires
            const Text(
              'Nouveau Créneau Horaire',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text('Matinée', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _morningSlots.map((slot) => _buildSlotChip(slot)).toList(),
            ),
            const SizedBox(height: 12),
            const Text('Après-midi', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _afternoonSlots.map((slot) => _buildSlotChip(slot)).toList(),
            ),
            const SizedBox(height: 20),

            // Motif
            const Text(
              'Motif de Consultation',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Veuillez saisir un motif' : null,
            ),
            const SizedBox(height: 20),

            // Rappel & Notification
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Rappel avant le rendez-vous',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      Switch.adaptive(
                        value: _enableNotification,
                        onChanged: (val) => setState(() => _enableNotification = val),
                      ),
                    ],
                  ),
                  if (_enableNotification) ...[
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    Wrap(
                      spacing: 8,
                      children: ReminderOption.values
                          .where((r) => r != ReminderOption.none)
                          .map((opt) {
                            return ChoiceChip(
                              label: Text(opt.label),
                              selected: _selectedReminder == opt,
                              onSelected: (sel) {
                                if (sel) setState(() => _selectedReminder = opt);
                              },
                            );
                          })
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Bouton Enregistrer
            ElevatedButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Enregistrer les modifications'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotChip(String slot) {
    final isSelected = _selectedSlot == slot;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => setState(() => _selectedSlot = slot),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? theme.colorScheme.primary : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          slot,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
