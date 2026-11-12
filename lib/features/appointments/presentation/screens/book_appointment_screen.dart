import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/doctor.dart';
import '../controllers/appointments_controller.dart';
import '../widgets/add_edit_doctor_dialog.dart';

/// Écran de prise de rendez-vous avec choix de date, créneaux et notifications de rappel
class BookAppointmentScreen extends ConsumerStatefulWidget {
  final Doctor? initialDoctor;

  const BookAppointmentScreen({
    super.key,
    this.initialDoctor,
  });

  @override
  ConsumerState<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();

  Doctor? _selectedDoctor;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedSlot = '10:00';
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _enableNotification = true;
  ReminderOption _selectedReminder = ReminderOption.oneDayBefore;

  final List<String> _morningSlots = ['09:00', '09:30', '10:00', '10:30', '11:00', '11:30'];
  final List<String> _afternoonSlots = ['14:00', '14:30', '15:00', '15:30', '16:00', '16:30'];

  @override
  void initState() {
    super.initState();
    _selectedDoctor = widget.initialDoctor;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now.add(const Duration(days: 1)) : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _confirmAppointment() async {
    if (_selectedDoctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un médecin'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedDate.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La date du rendez-vous doit être dans le futur'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final newAppointment = Appointment(
        id: 'apt-${DateTime.now().millisecondsSinceEpoch}',
        doctorId: _selectedDoctor!.id,
        doctorName: _selectedDoctor!.fullName,
        doctorSpecialty: _selectedDoctor!.specialty,
        doctorAddress: _selectedDoctor!.address,
        doctorPhone: _selectedDoctor!.phone,
        dateTime: _selectedDate,
        timeSlot: _selectedSlot,
        reason: _reasonController.text.trim(),
        status: AppointmentStatus.upcoming,
        reminder: _selectedReminder,
        notificationEnabled: _enableNotification,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        fee: _selectedDoctor!.consultationFee,
      );

      final success = await ref.read(appointmentsNotifierProvider.notifier).createAppointment(newAppointment);

      if (!mounted) return;

      if (!success) {
        final error = ref.read(appointmentsNotifierProvider).errorMessage ?? 'Erreur lors de la réservation';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
        );
        return;
      }

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
              Text('Médecin : ${_selectedDoctor!.fullName} (${_selectedDoctor!.specialty})'),
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
    final availableDoctors = ref.watch(appointmentsNotifierProvider).doctors;

    if (_selectedDoctor == null && availableDoctors.isNotEmpty) {
      _selectedDoctor = availableDoctors.first;
    } else if (_selectedDoctor != null && !availableDoctors.any((d) => d.id == _selectedDoctor!.id)) {
      _selectedDoctor = availableDoctors.isNotEmpty ? availableDoctors.first : null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prendre un Rendez-vous'),
      ),
      body: availableDoctors.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 60, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucun médecin disponible dans l\'annuaire',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text('Ajoutez un médecin pour pouvoir planifier un rendez-vous.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => AddEditDoctorDialog.show(context),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Ajouter un médecin'),
                  ),
                ],
              ),
            )
          : Form(
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
                        items: availableDoctors.map((doc) {
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
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => context.push('/appointments/orientation'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 15, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Quelle spécialité consulter ? Se faire orienter par l\'IA',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

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
                  _buildSectionHeader('4. Motif de la consultation *', Icons.edit_note_rounded),
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

                  // Étape 5 : Notifications et Rappels
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
                          const Divider(height: 24, color: Color(0xFFF1F5F9)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Délai du rappel',
                                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFF334155)),
                              ),
                              DropdownButton<ReminderOption>(
                                value: _selectedReminder,
                                underline: const SizedBox.shrink(),
                                items: ReminderOption.values.map((opt) {
                                  return DropdownMenuItem<ReminderOption>(
                                    value: opt,
                                    child: Text(opt.label, style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (opt) {
                                  if (opt != null) {
                                    setState(() => _selectedReminder = opt);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Étape 6 : Notes personnelles (Optionnel)
                  _buildSectionHeader('6. Notes pour la consultation (optionnel)', Icons.note_alt_outlined),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Ex: Penser à apporter les résultats du scanner...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Bouton de confirmation
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _confirmAppointment,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text(
                        'Confirmer le rendez-vous',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  Widget _buildSlotChip(String slot) {
    final isSelected = _selectedSlot == slot;
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Text(slot),
      selected: isSelected,
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF334155),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedSlot = slot;
          });
        }
      },
    );
  }
}
