import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/medication_repository.dart';
import '../../domain/entities/medication.dart';

class MedicationsDashboardScreen extends StatefulWidget {
  const MedicationsDashboardScreen({super.key, this.repository});

  final MedicationRepository? repository;

  @override
  State<MedicationsDashboardScreen> createState() =>
      _MedicationsDashboardScreenState();
}

class _MedicationsDashboardScreenState
    extends State<MedicationsDashboardScreen> {
  MedicationRepository get _repository =>
      widget.repository ?? MedicationRepository.instance;
  late Future<List<Medication>> _medications;

  @override
  void initState() {
    super.initState();
    _medications = _repository.getAll();
  }

  Future<void> _open(String location) async {
    await context.push<bool>(location);
    if (mounted) {
      setState(() {
        _medications = _repository.getAll();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Médicaments & Traitements',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: FutureBuilder<List<Medication>>(
        future: _medications,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _loadError();
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final medications = snapshot.data!;
          final today = DateUtils.dateOnly(DateTime.now());
          final todaysMedications = medications.where((medication) {
            final start = DateUtils.dateOnly(medication.startDate);
            final end = DateUtils.dateOnly(medication.endDate);
            return !today.isBefore(start) && !today.isAfter(end);
          }).toList()..sort(_compareSchedule);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              const Text(
                'Mes traitements',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Gérez vos médicaments, horaires et rappels.',
                style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 25),
              _sectionTitle('Tous mes médicaments'),
              const SizedBox(height: 15),
              if (medications.isEmpty)
                _emptyState(
                  'Aucun médicament enregistré',
                  'Ajoutez un traitement pour le retrouver ici.',
                )
              else
                ...medications.map(
                  (medication) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MedicationCard(
                      medication: medication,
                      onTap: () =>
                          _open('/medications/detail?id=${medication.id}'),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              _sectionTitle('Aujourd’hui'),
              const SizedBox(height: 15),
              if (todaysMedications.isEmpty)
                _emptyState(
                  'Aucune prise prévue aujourd’hui',
                  'Les traitements actifs à cette date apparaîtront ici.',
                )
              else
                ...todaysMedications.map(
                  (medication) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TodayMedicationCard(medication: medication),
                  ),
                ),
              const SizedBox(height: 18),
              _sectionTitle('Accès rapide'),
              const SizedBox(height: 15),
              _quickLink(
                icon: Icons.access_time,
                title: 'Horaires de prise',
                subtitle: 'Consulter le planning des médicaments',
                onTap: () => _open('/medications/schedule'),
              ),
              const SizedBox(height: 12),
              _quickLink(
                icon: Icons.notifications_outlined,
                title: 'Rappels',
                subtitle: 'Gérer les rappels de vos traitements',
                onTap: () => _open('/medications/reminders'),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        onPressed: () => _open('/medications/add'),
        icon: const Icon(Icons.add),
        label: const Text(
          'Ajouter',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _loadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Impossible de charger les médicaments.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFB91C1C)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _medications = _repository.getAll();
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Color(0xFF0F172A),
    ),
  );

  Widget _emptyState(String title, String description) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      children: [
        const Icon(Icons.medication_outlined, color: Color(0xFF0D9488)),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
      ],
    ),
  );

  Widget _quickLink({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: const Color(0xFFCCFBF1),
              child: Icon(icon, color: const Color(0xFF0D9488)),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    ),
  );

  int _compareSchedule(Medication first, Medication second) =>
      first.time.compareTo(second.time);
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.medication, required this.onTap});

  final Medication medication;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundColor: Color(0xFFCCFBF1),
              child: Icon(
                Icons.medication_outlined,
                color: Color(0xFF0D9488),
                size: 28,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${medication.dosage} • ${medication.time}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    ),
  );
}

class _TodayMedicationCard extends StatelessWidget {
  const _TodayMedicationCard({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFFCCFBF1),
          child: Icon(Icons.access_time, color: Color(0xFF0D9488)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${medication.time} • ${medication.name}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                medication.dosage,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        if (medication.reminderEnabled)
          const Tooltip(
            message: 'Rappel activé',
            child: Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFF0D9488),
            ),
          ),
      ],
    ),
  );
}
