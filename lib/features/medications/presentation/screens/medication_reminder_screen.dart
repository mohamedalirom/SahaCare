import 'package:flutter/material.dart';

import '../../data/medication_repository.dart';
import '../../domain/entities/medication.dart';

class MedicationReminderScreen extends StatefulWidget {
  const MedicationReminderScreen({super.key, this.repository});

  final MedicationRepository? repository;

  @override
  State<MedicationReminderScreen> createState() =>
      _MedicationReminderScreenState();
}

class _MedicationReminderScreenState extends State<MedicationReminderScreen> {
  MedicationRepository get _repository =>
      widget.repository ?? MedicationRepository.instance;
  late Future<List<Medication>> _medications;
  int? _savingId;

  @override
  void initState() {
    super.initState();
    _medications = _repository.getAll();
  }

  Future<void> _setReminder(Medication medication, bool enabled) async {
    final id = medication.id;
    if (id == null) {
      throw StateError('Le médicament ne possède pas d’identifiant.');
    }
    setState(() => _savingId = id);
    try {
      final changed = await _repository.update(
        medication.copyWith(reminderEnabled: enabled),
      );
      if (changed == 0) {
        throw StateError('Ce médicament a été supprimé.');
      }
      if (mounted) {
        setState(() {
          _savingId = null;
          _medications = _repository.getAll();
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de modifier le rappel : $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Rappels de médicaments',
        style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
    ),
    body: FutureBuilder<List<Medication>>(
      future: _medications,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Impossible de charger les rappels.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final medications = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Mes rappels',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Activez ou désactivez les rappels de vos traitements.',
              style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 25),
            if (medications.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Aucun médicament enregistré.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              )
            else
              ...medications.map(
                (medication) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReminderCard(
                    medication: medication,
                    saving: medication.id == _savingId,
                    onChanged: (value) => _setReminder(medication, value),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const Text(
              'Informations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF0D9488),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ce réglage enregistre votre préférence de rappel pour chaque traitement.',
                      style: TextStyle(color: Color(0xFF0F172A), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.medication,
    required this.saving,
    required this.onChanged,
  });

  final Medication medication;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFCCFBF1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: Color(0xFF0D9488),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medication.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${medication.dosage} • ${medication.time}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        if (saving)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Switch(
            value: medication.reminderEnabled,
            activeThumbColor: const Color(0xFF0D9488),
            onChanged: onChanged,
          ),
      ],
    ),
  );
}
