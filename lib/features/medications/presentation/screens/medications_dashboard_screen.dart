import '../widgets/medication_scaffold.dart';
import '../widgets/medication_notification_panel.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/medication_repository.dart';
import '../../domain/entities/medication.dart';
import '../widgets/medication_dashboard_visuals.dart';

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

  Future<void> _reviewStock(Medication medication) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Présentation et stock à vérifier'),
        content: const SingleChildScrollView(
          child: Text(
            'Vérifiez la présentation sur la boîte avant toute correction. '
            'Si la présentation enregistrée est incorrecte, utilisez Modifier dans la fiche du traitement. '
            'L’unité du stock existant est verrouillée pour préserver son historique : '
            'sa correction nécessite une procédure explicite distincte. '
            'Aucune quantité ni unité ne sera modifiée ici.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Fermer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vérifier la fiche'),
          ),
        ],
      ),
    );
    if (!mounted || open != true) return;
    await _open('/medications/detail?id=${medication.id}');
  }

  Future<void> _openStockPicker(List<Medication> medications) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .65,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: CustomScrollView(
              shrinkWrap: true,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gestion du stock',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choisissez un traitement pour consulter son stock.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
                if (medications.isEmpty)
                  SliverToBoxAdapter(
                    child: DashboardEmptyState(
                      title: 'Votre stock commence ici',
                      description: 'Ajoutez un traitement pour choisir son unité et sa quantité.',
                      onAdd: () => Navigator.pop(sheetContext, -1),
                    ),
                  )
                else
                  SliverList.list(
                    children: [
                      for (final medication in medications)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xFF0D9488),
                          ),
                          title: Text(medication.name),
                          subtitle: Text(
                            medication.stock?.enabled == true
                                ? '${medication.stock!.remaining.display} ${medication.stock!.unit.label}'
                                : 'Suivi du stock désactivé',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF94A3B8),
                          ),
                          onTap: medication.id == null
                              ? null
                              : () =>
                                    Navigator.pop(sheetContext, medication.id),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    await _open(
      selected == -1 ? '/medications/add' : '/medications/detail?id=$selected',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MedicationScaffold(
      manageNotifications: widget.repository == null,
      reserveNavigationSpace: true,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        toolbarHeight: (56 * MediaQuery.textScalerOf(context).scale(18) / 18)
            .clamp(56, 112)
            .toDouble(),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.medication_outlined,
                color: Color(0xFF0D9488),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Médicaments & Traitements',
                maxLines: 2,
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: -.4,
                ),
              ),
            ),
          ],
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              const DashboardHero(),
              const SizedBox(height: 12),
              DashboardOverview(
                activeCount: medications
                    .where((m) => m.isActiveOn(today))
                    .length,
                doseCount: todaysDoses.length,
              ),
              const SizedBox(height: 20),
              _calendarCard(onTap: () => _open('/medications/schedule')),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _open('/medications/schedule'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0D9488),
                  ),
                  icon: const Icon(Icons.access_time_rounded, size: 17),
                  label: const Text('Horaires de prise'),
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Votre espace de suivi'),
              const SizedBox(height: 12),
              DashboardToolGrid(
                tools: [
                  DashboardTool(
                    icon: Icons.insights_outlined,
                    title: 'Mes statistiques',
                    subtitle: 'Votre régularité sur 7 ou 30 jours',
                    onTap: () => _open('/medications/statistics'),
                  ),
                  DashboardTool(
                    icon: Icons.description_outlined,
                    title: 'Rapport médical',
                    subtitle: 'Votre suivi au format PDF',
                    onTap: () => _open('/medications/report'),
                  ),
                  DashboardTool(
                    icon: Icons.inventory_2_outlined,
                    title: 'Gestion du stock',
                    subtitle: 'Les quantités par médicament',
                    onTap: () => _openStockPicker(medications),
                  ),
                  DashboardTool(
                    icon: Icons.notifications_outlined,
                    title: 'Rappels',
                    subtitle: 'Vos préférences de notification',
                    onTap: () => _open('/medications/reminders'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DashboardScannerBanner(onTap: () => _open('/medications/scan')),
              const SizedBox(height: 24),
              _sectionTitle(switch (_filter) {
                _MedicationFilter.active => 'Traitements actifs',
                _MedicationFilter.completed => 'Traitements terminés',
                _MedicationFilter.all => 'Tous mes médicaments',
              }),
              const SizedBox(height: 12),
              SegmentedButton<_MedicationFilter>(
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
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
              const SizedBox(height: 14),
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
                    child: DashboardMedicationCard(
                      medication: medication,
                      onReviewStock: () => _reviewStock(medication),
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
                    child: DashboardDoseTile(
                      onTap: () => _open('/medications/schedule'),
                      medication: dose.key,
                      time: dose.value,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              if (widget.repository == null) ...[
                const MedicationNotificationPanel(),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
      bottomAction: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            key: const ValueKey('add-medication-button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: const Color(0xFF0D9488).withValues(alpha: .22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
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

  Widget _sectionTitle(String title) => Row(
    children: [
      Container(
        width: 3,
        height: 18,
        decoration: BoxDecoration(
          color: const Color(0xFF0D9488),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    ],
  );

  Widget _emptyState(String title, String description) => DashboardEmptyState(
    title: title,
    description: description,
    onAdd: title == 'Aucun médicament enregistré'
        ? () => _open('/medications/add')
        : null,
  );

  int _compareSchedule(Medication first, Medication second) =>
      _timesFor(first).first.compareTo(_timesFor(second).first);

  List<String> _timesFor(Medication medication) =>
      medication.scheduleTimes.isEmpty
      ? [medication.time]
      : medication.scheduleTimes;
}
