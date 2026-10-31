import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/medication_repository.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_occurrence.dart';

class MedicationDetailScreen extends StatefulWidget {
  const MedicationDetailScreen({super.key, this.medicationId, this.repository});

  final int? medicationId;
  final MedicationRepository? repository;

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  MedicationRepository get _repository =>
      widget.repository ?? MedicationRepository.instance;
  late Future<Medication?> _medication;
  late Future<List<MedicationOccurrence>> _occurrences;
  bool _deleting = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _medication = _loadMedication();
    _occurrences = _loadOccurrences();
  }

  Future<Medication?> _loadMedication() {
    final id = widget.medicationId;
    if (id == null) return Future.value(null);
    return _repository.getById(id);
  }

  Future<List<MedicationOccurrence>> _loadOccurrences() {
    final id = widget.medicationId;
    if (id == null) return Future.value(const []);
    return _repository.getOccurrencesForMedication(id);
  }

  Future<void> _edit() async {
    final id = widget.medicationId;
    if (id == null) return;
    final changed = await context.push<bool>('/medications/edit?id=$id');
    if (changed == true && mounted) {
      setState(() {
        _hasChanges = true;
        _medication = _loadMedication();
        _occurrences = _loadOccurrences();
      });
    }
  }

  Future<void> _delete(Medication medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le traitement ?'),
        content: Text('Voulez-vous supprimer ${medication.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final id = medication.id;
      if (id == null || await _repository.delete(id) == 0) {
        throw StateError('Ce médicament a déjà été supprimé.');
      }
      if (mounted) context.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de supprimer le médicament : $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => context.pop(_hasChanges),
        icon: const Icon(Icons.arrow_back),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Détail du traitement',
        style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
    ),
    body: FutureBuilder<Medication?>(
      future: _medication,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Impossible de charger ce médicament.'),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final medication = snapshot.data;
        if (medication == null) {
          return const Center(child: Text('Ce médicament est introuvable.'));
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFCCFBF1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  size: 42,
                  color: Color(0xFF0D9488),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Center(
              child: Text(
                medication.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Détails enregistrés du traitement',
                style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 20),
            if (medication.activeIngredient case final ingredient?) ...[
              _informationCard(
                icon: Icons.science_outlined,
                title: 'Substance active',
                value: ingredient,
              ),
              const SizedBox(height: 12),
            ],
            if (medication.commercialPresentation case final presentation?) ...[
              _informationCard(
                icon: Icons.medication_outlined,
                title: 'Présentation commerciale',
                value: presentation,
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _edit,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D9488),
                side: const BorderSide(color: Color(0xFF0D9488)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text(
                'Modifier le traitement',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 25),
            _informationCard(
              icon: Icons.science_outlined,
              title: 'Dosage',
              value: medication.dosage,
            ),
            const SizedBox(height: 12),
            _informationCard(
              icon: Icons.access_time,
              title: 'Horaires de prise',
              value:
                  (medication.scheduleTimes.isEmpty
                          ? [medication.time]
                          : medication.scheduleTimes)
                      .join(' • '),
            ),
            const SizedBox(height: 12),
            _informationCard(
              icon: Icons.calendar_view_week_outlined,
              title: 'Jours de prise',
              value: _formatWeekdays(medication.weekdaysMask),
            ),
            const SizedBox(height: 12),
            _informationCard(
              icon: Icons.calendar_today_outlined,
              title: 'Date de début',
              value: _formatDate(medication.startDate),
            ),
            const SizedBox(height: 12),
            _informationCard(
              icon: Icons.event_outlined,
              title: 'Date de fin',
              value: medication.endDate == null
                  ? 'Sans date de fin'
                  : _formatDate(medication.endDate!),
            ),
            const SizedBox(height: 20),
            _occurrenceHistory(),
            const SizedBox(height: 12),
            _informationCard(
              icon: Icons.notifications_outlined,
              title: 'Rappel',
              value: medication.reminderEnabled ? 'Activé' : 'Désactivé',
            ),
            const SizedBox(height: 30),
            OutlinedButton.icon(
              onPressed: _deleting ? null : () => _delete(medication),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: const Text(
                'Supprimer le traitement',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _informationCard({
    required IconData icon,
    required String title,
    required String value,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFCCFBF1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF0D9488)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _formatWeekdays(int mask) {
    const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final selected = [
      for (var index = 0; index < labels.length; index++)
        if (mask & (1 << index) != 0) labels[index],
    ];
    return selected.join(', ');
  }

  Widget _occurrenceHistory() => FutureBuilder<List<MedicationOccurrence>>(
    future: _occurrences,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text(
          'Impossible de charger l’historique des prises.',
          style: TextStyle(color: Color(0xFFB91C1C)),
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ),
        );
      }
      final occurrences = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historique des prises',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          if (occurrences.isEmpty)
            const Text(
              'Aucune prise enregistrée pour le moment.',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else
            ...occurrences.map(
              (occurrence) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _informationCard(
                  icon: Icons.history,
                  title:
                      '${_formatDate(occurrence.effectiveDate)} • ${occurrence.effectiveTime}',
                  value: occurrence.statusLabel(),
                ),
              ),
            ),
        ],
      );
    },
  );
}
