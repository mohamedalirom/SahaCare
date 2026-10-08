import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/doctor.dart';

/// Écran de prise de rendez-vous avec choix de date, créneaux et notifications de rappel
class BookAppointmentScreen extends StatefulWidget {
  final Doctor? initialDoctor;

  const BookAppointmentScreen({
    super.key,
    this.initialDoctor,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();

  late Doctor _selectedDoctor;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedSlot = '10:00';
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _enableNotification = true;
  ReminderOption _selectedReminder = ReminderOption.oneDayBefore;

  final List<Doctor> _availableDoctors = Doctor.mockDoctors;

  final List<String> _morningSlots = ['09:00', '09:30', '10:00', '10:30', '11:00', '11:30'];
  final List<String> _afternoonSlots = ['14:00', '14:30', '15:00', '15:30', '16:00', '16:30'];

  @override
  void initState() {
    super.initState();
    _selectedDoctor = widget.initialDoctor ?? _availableDoctors.first;
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

  void _confirmAppointment() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Rendez-vous Confirmé !'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Médecin : ${_selectedDoctor.fullName} (${_selectedDoctor.specialty})'),
              const SizedBox(height: 6),
              Text('Date : ${AppUtils.formatDate(_selectedDate)} à $_selectedSlot'),
              const SizedBox(height: 6),
              if (_enableNotification)
                Text(
                  'Rappel programmé : ${_selectedReminder.label}',
                  style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              child: const Text('Voir mes rendez-vous'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prendre un Rendez-vous'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Étape 1 : Sélection du Médecin
            _buildSectionHeader('1. Praticien & Spécialité', Icons.person_search_rounded),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Doctor>(
                  value: _selectedDoctor,
                  isExpanded: true,
                  items: _availableDoctors.map((doc) {
                    return DropdownMenuItem<Doctor>(
                      value: doc,
                      child: Row(
                        children: [
                          Icon(Icons.medical_services_outlined, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${doc.fullName} - ${doc.specialty} (${doc.consultationFee.toInt()} DT)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (doc) {
                    if (doc != null) {
                      setState(() => _selectedDoctor = doc);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Étape 2 : Choix de la Date
            _buildSectionHeader('2. Date de consultation', Icons.calendar_today_rounded),
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
                        Icon(Icons.event_available_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          AppUtils.formatDate(_selectedDate),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    Text(
                      'Modifier la date',
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Étape 3 : Sélection du Créneau Horaire
            _buildSectionHeader('3. Créneau horaire disponible', Icons.access_time_filled_rounded),
            const SizedBox(height: 8),
            const Text(
              'Matinée',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _morningSlots.map((slot) => _buildSlotChip(slot)).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Après-midi',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _afternoonSlots.map((slot) => _buildSlotChip(slot)).toList(),
            ),
            const SizedBox(height: 20),

            // Étape 4 : Motif de consultation
            _buildSectionHeader('4. Motif de la consultation', Icons.edit_note_rounded),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                hintText: 'Ex: Contrôle régulier, Douleur thoracique, Bilan...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Veuillez préciser le motif de consultation';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Étape 5 : Notifications et Rappels (Exigence Dali)
            _buildSectionHeader('5. Notifications & Rappels de RDV', Icons.notifications_active_rounded),
            const SizedBox(height: 8),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activer le rappel automatique',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Recevez une alerte avant la consultation',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
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
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Moment du rappel :',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ReminderOption.values
                          .where((r) => r != ReminderOption.none)
                          .map((opt) {
                            final isSel = _selectedReminder == opt;
                            return ChoiceChip(
                              label: Text(opt.label),
                              selected: isSel,
                              onSelected: (selected) {
                                if (selected) setState(() => _selectedReminder = opt);
                              },
                            );
                          })
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Notes complémentaires
            _buildSectionHeader('6. Notes pour le médecin (optionnel)', Icons.note_alt_outlined),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ex: Antécédents récents, allergies...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 28),

            // Bouton de validation
            ElevatedButton.icon(
              onPressed: _confirmAppointment,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Confirmer la prise de rendez-vous'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
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
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : const Color(0xFFCBD5E1),
          ),
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
