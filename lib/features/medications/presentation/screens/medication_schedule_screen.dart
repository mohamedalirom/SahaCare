import 'package:flutter/material.dart';

import '../../data/medication_repository.dart';
import '../../domain/entities/medication.dart';

class MedicationScheduleScreen extends StatefulWidget {
  const MedicationScheduleScreen({super.key, this.repository});

  final MedicationRepository? repository;

  @override
  State<MedicationScheduleScreen> createState() =>
      _MedicationScheduleScreenState();
}

class _MedicationScheduleScreenState extends State<MedicationScheduleScreen> {
  MedicationRepository get _repository =>
      widget.repository ?? MedicationRepository.instance;
  late Future<List<Medication>> _medications;

  @override
  void initState() {
    super.initState();
    _medications = _repository.getAll();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Horaires de prise',
        style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
    ),
    body: FutureBuilder<List<Medication>>(
      future: _medications,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Impossible de charger les horaires.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final today = DateUtils.dateOnly(DateTime.now());
        final todayMedications = snapshot.data!.where((medication) {
          final start = DateUtils.dateOnly(medication.startDate);
          final end = DateUtils.dateOnly(medication.endDate);
          return !today.isBefore(start) && !today.isAfter(end);
        }).toList()..sort((a, b) => a.time.compareTo(b.time));

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Planning du jour',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Consultez les heures prévues pour vos traitements.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 25),
            if (todayMedications.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Aucune prise prévue aujourd’hui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              )
            else
              ...todayMedications.map(
                (medication) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ScheduleCard(medication: medication),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFCCFBF1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.access_time, color: Color(0xFF0D9488)),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medication.time,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${medication.name} • ${medication.dosage}',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        if (medication.reminderEnabled)
          const Icon(
            Icons.notifications_active_outlined,
            color: Color(0xFF0D9488),
          ),
      ],
    ),
  );
}
