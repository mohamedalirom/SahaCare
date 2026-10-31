import '../widgets/medication_scaffold.dart';
import '../widgets/medication_notification_panel.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/medication_repository.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_stock.dart';

enum _MedicationFilter { active, completed, all }

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
  _MedicationFilter _filter = _MedicationFilter.all;

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
    return MedicationScaffold(
      manageNotifications: widget.repository == null,
      reserveNavigationSpace: true,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Médicaments & Traitements',
          maxLines: 2,
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
          final todaysMedications =
              medications
                  .where(
                    (medication) =>
                        medication.isActiveOn(today) &&
                        medication.weekdaysMask & (1 << (today.weekday - 1)) !=
                            0,
                  )
                  .toList()
                ..sort(_compareSchedule);
          final todaysDoses = <MapEntry<Medication, String>>[
            for (final medication in todaysMedications)
              for (final time in _timesFor(medication))
                MapEntry(medication, time),
          ]..sort((first, second) => first.value.compareTo(second.value));
          final visibleMedications = medications.where((medication) {
            final endDate = medication.endDate == null
                ? null
                : DateUtils.dateOnly(medication.endDate!);
            return switch (_filter) {
              _MedicationFilter.active =>
                endDate == null || !today.isAfter(endDate),
              _MedicationFilter.completed =>
                endDate != null && today.isAfter(endDate),
              _MedicationFilter.all => true,
            };
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
              if (widget.repository == null) ...[
                const MedicationNotificationPanel(),
                const SizedBox(height: 16),
              ],
              SegmentedButton<_MedicationFilter>(
                segments: const [
                  ButtonSegment(
                    value: _MedicationFilter.active,
                    label: Text('Actifs'),
                  ),
                  ButtonSegment(
                    value: _MedicationFilter.completed,
                    label: Text('Terminés'),
                  ),
                  ButtonSegment(
                    value: _MedicationFilter.all,
                    label: Text('Tous'),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (selection) =>
                    setState(() => _filter = selection.first),
              ),
              const SizedBox(height: 20),
              _calendarCard(onTap: () => _open('/medications/schedule')),
              const SizedBox(height: 22),
              _sectionTitle(switch (_filter) {
                _MedicationFilter.active => 'Traitements actifs',
                _MedicationFilter.completed => 'Traitements terminés',
                _MedicationFilter.all => 'Tous mes médicaments',
              }),
              const SizedBox(height: 15),
              if (visibleMedications.isEmpty)
                _emptyState(
                  _filter == _MedicationFilter.completed
                      ? 'Aucun traitement terminé'
                      : 'Aucun médicament enregistré',
                  _filter == _MedicationFilter.completed
                      ? 'Les traitements terminés resteront consultables ici.'
                      : 'Ajoutez un traitement pour le retrouver ici.',
                )
              else
                ...visibleMedications.map(
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
              if (todaysDoses.isEmpty)
                _emptyState(
                  'Aucune prise prévue aujourd’hui',
                  'Les traitements actifs à cette date apparaîtront ici.',
                )
              else
                ...todaysDoses.map(
                  (dose) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TodayMedicationCard(
                      medication: dose.key,
                      time: dose.value,
                    ),
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
      bottomAction: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            key: const ValueKey('add-medication-button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () => _open('/medications/add'),
            icon: const Icon(Icons.add),
            label: const Text(
              'Ajouter',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendarCard({required VoidCallback onTap}) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(20),
    child: Ink(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        key: const ValueKey('open-medication-calendar'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mon calendrier thérapeutique',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Consultez vos prises par jour, semaine ou mois',
                      style: TextStyle(color: Color(0xFFD9F6F1), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    ),
  );

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
      _timesFor(first).first.compareTo(_timesFor(second).first);

  List<String> _timesFor(Medication medication) =>
      medication.scheduleTimes.isEmpty
      ? [medication.time]
      : medication.scheduleTimes;
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
                  if (medication.activeIngredient case final ingredient?)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Substance active : $ingredient',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  if (medication.commercialPresentation
                      case final presentation?)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Présentation : $presentation',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  const SizedBox(height: 5),
                  Text(
                    '${medication.dosage} • ${_scheduleTimes(medication)}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  if (medication.stock case final stock?) ...[
                    const SizedBox(height: 6),
                    Text(
                      !stock.enabled
                          ? 'Suivi du stock désactivé'
                          : stock.pendingAnomalies > 0
                          ? 'Stock à régulariser : ${stock.pendingAnomalies} anomalie(s)'
                          : 'Stock : ${stock.remaining.display} ${stock.unit.label}'
                                '${stock.alert == StockAlert.low || stock.alert == StockAlert.empty ? ' • Stock faible' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            stock.alert == StockAlert.anomaly ||
                                stock.alert == StockAlert.empty
                            ? const Color(0xFFDC2626)
                            : stock.alert == StockAlert.low
                            ? const Color(0xFFD97706)
                            : const Color(0xFF0D9488),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    ),
  );

  String _scheduleTimes(Medication medication) =>
      (medication.scheduleTimes.isEmpty
              ? [medication.time]
              : medication.scheduleTimes)
          .join(' • ');
}

class _TodayMedicationCard extends StatelessWidget {
  const _TodayMedicationCard({required this.medication, required this.time});

  final Medication medication;
  final String time;

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
                '$time • ${medication.name}',
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
