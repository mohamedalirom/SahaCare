import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/medication_repository.dart';
import '../../domain/services/medication_adherence.dart';
import '../widgets/medication_scaffold.dart';
import '../widgets/medication_visuals.dart';
import '../widgets/adherence_dashboard_cards.dart';

const _turquoise = Color(0xFF0D9488);
const _muted = Color(0xFF64748B);
Color _statusColor(AdherenceStatus status) => switch (status) {
  AdherenceStatus.confirmed => _turquoise,
  AdherenceStatus.missed => const Color(0xFFDC2626),
  AdherenceStatus.ignored => const Color(0xFF64748B),
  AdherenceStatus.postponed => const Color(0xFF6366F1),
  AdherenceStatus.late => const Color(0xFFD97706),
  AdherenceStatus.pending => const Color(0xFF0284C7),
  AdherenceStatus.future => const Color(0xFF94A3B8),
};
String _rate(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(1).replaceAll('.', ',')} %';
String _date(DateTime date) =>
    DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());

class MedicationStatisticsScreen extends StatefulWidget {
  const MedicationStatisticsScreen({super.key, this.repository, this.clock});
  final MedicationRepository? repository;
  final DateTime Function()? clock;
  @override
  State<MedicationStatisticsScreen> createState() =>
      _MedicationStatisticsScreenState();
}

class _MedicationStatisticsScreenState extends State<MedicationStatisticsScreen>
    with WidgetsBindingObserver {
  MedicationRepository get _repository =>
      widget.repository ?? MedicationRepository.instance;
  int _days = 7;
  int? _medicationId;
  DateTime? _selectedDay;
  late Future<AdherenceReport> _report;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _report = _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<AdherenceReport> _load() async {
    final now = (widget.clock?.call() ?? DateTime.now()).toLocal();
    final from = DateTime(now.year, now.month, now.day - _days + 1);
    final days = _days;
    final records = await _repository.getAdherenceRecords(
      from: from,
      through: now,
    );
    return MedicationAdherenceCalculator().calculate(
      records,
      days: days,
      now: now,
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _report = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => MedicationScaffold(
    // This dashboard only reads SQLite; no notification synchronization/backfill.
    manageNotifications: false,
    backgroundColor: MedicationColors.canvas,
    appBar: AppBar(
      title: const Text(
        'Mes statistiques',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: MedicationColors.ink,
        ),
      ),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: MedicationColors.ink),
      actions: [
        IconButton(
          key: const ValueKey('statistics-refresh'),
          tooltip: 'Actualiser',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded, color: MedicationColors.teal),
          style: IconButton.styleFrom(backgroundColor: const Color(0xFFEAF6F2)),
        ),
      ],
    ),
    body: FutureBuilder<AdherenceReport>(
      future: _report,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: _turquoise),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Impossible de lire les statistiques. Vos données sont conservées.',
                  ),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }
        final all = snapshot.data!;
        final chosenId = all.medications.any((m) => m.id == _medicationId)
            ? _medicationId
            : null;
        final records = all.entries
            .where(
              (e) =>
                  chosenId == null ||
                  e.record.occurrence.medicationId == chosenId,
            )
            .map((e) => e.record)
            .toList();
        final report = MedicationAdherenceCalculator().calculate(
          records,
          days: _days,
          now: all.now,
        );
        final history = report.entries
            .where(
              (e) =>
                  _selectedDay == null ||
                  MedicationAdherenceCalculator.dateOnly(
                        e.record.effectiveAt,
                      ) ==
                      _selectedDay,
            )
            .toList();
        return RefreshIndicator(
          onRefresh: () async {
            _refresh();
            try {
              await _report;
            } catch (_) {
              // The FutureBuilder displays the read error and retry action.
            }
          },
          child: ListView(
            key: const ValueKey('statistics-list'),
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const Text(
                'Chaque prise compte.',
                style: TextStyle(
                  fontSize: 26,
                  letterSpacing: -.7,
                  fontWeight: FontWeight.w800,
                  color: MedicationColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Un regard clair sur vos habitudes de traitement.',
                style: TextStyle(
                  color: MedicationColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${DateFormat('dd/MM').format(report.from)} — ${DateFormat('dd/MM/yyyy').format(report.now)} · heure locale',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                key: const ValueKey('adherence-period'),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: const Color(0xFFCCFBF1),
                  selectedForegroundColor: _turquoise,
                  backgroundColor: Colors.white,
                  foregroundColor: MedicationColors.muted,
                  side: const BorderSide(color: MedicationColors.line),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 jours')),
                  ButtonSegment(value: 30, label: Text('30 jours')),
                ],
                selected: {_days},
                onSelectionChanged: (value) => setState(() {
                  _days = value.single;
                  _selectedDay = null;
                  _report = _load();
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(
                  'adherence-medication-$chosenId-${all.medications.length}',
                ),
                initialValue: chosenId ?? -1,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Médicament',
                  prefixIcon: Icon(
                    Icons.medication_outlined,
                    color: MedicationColors.teal,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  labelStyle: TextStyle(
                    color: MedicationColors.muted,
                    fontSize: 13,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: MedicationColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: MedicationColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(
                      color: MedicationColors.teal,
                      width: 1.5,
                    ),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: -1,
                    child: Text('Tous les médicaments'),
                  ),
                  ...all.medications.map(
                    (m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(
                        '${m.name}${m.archived
                            ? ' · Archivé'
                            : m.completed
                            ? ' · Terminé'
                            : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _medicationId = value == -1 ? null : value;
                  _selectedDay = null;
                }),
              ),
              const SizedBox(height: 16),
              AdherenceOverviewCard(
                report: report,
                formattedRate: _rate(report.percentage),
              ),
              const SizedBox(height: 20),
              const Text(
                'Vos prises en un coup d’œil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MedicationColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              AdherenceStatusGrid(report: report, colorFor: _statusColor),
              const SizedBox(height: 12),
              MedicationSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: const ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: MedicationColors.teal,
                  ),
                  title: Text(
                    'Comprendre les chiffres',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MedicationColors.ink,
                    ),
                  ),
                  childrenPadding: EdgeInsets.only(bottom: 16),
                  children: [
                    Text(
                      'Le taux inclut uniquement les prises SQLite dont l’horaire effectif est échu : confirmées, manquées, ignorées, reportées, en retard ou en attente. '
                      'Un report remplace l’horaire initial, sans créer une deuxième prise. '
                      'En retard : non confirmée aujourd’hui depuis au moins 60 min. Manquée : non confirmée à une date locale passée. '
                      'Un report échu reste reporté. Une confirmation à partir de 60 min après l’horaire effectif est signalée tardive, sans double comptage. '
                      'Une prise future, même confirmée en avance, reste hors taux jusqu’à son échéance. '
                      'Les jours sans ligne SQLite ne prouvent ni une prise ni un oubli. Les données supprimées auparavant ne sont pas reconstituées.',
                      style: TextStyle(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (report.entries.isEmpty)
                _card(
                  'Aucune donnée enregistrée',
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: MedicationIllustration(size: 100)),
                      SizedBox(height: 12),
                      Text(
                        'Votre suivi commence ici',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: MedicationColors.ink,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Aucune prise enregistrée pour cette période. Retrouvez vos prises dans le calendrier : vos statistiques apparaîtront au fil de vos confirmations.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: MedicationColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              _card(
                'Évolution quotidienne',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Touchez un point pour filtrer l’historique. Les jours sans échéance n’ont pas de taux.',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 16),
                    if (report.denominator == 0)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Pas encore de courbe calculable.'),
                      )
                    else
                      SizedBox(
                        height: 220,
                        child: LineChart(
                          LineChartData(
                            minX: 0,
                            maxX: (_days - 1).toDouble(),
                            minY: 0,
                            maxY: 100,
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(
                              drawVerticalLine: false,
                              horizontalInterval: 25,
                              getDrawingHorizontalLine: (value) => const FlLine(
                                color: Color(0xFFE5EEEF),
                                strokeWidth: 1,
                                dashArray: [4, 5],
                              ),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 42,
                                  interval: 50,
                                  getTitlesWidget: (value, meta) => Text(
                                    '${value.toInt()} %',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  interval: _days == 7 ? 2 : 7,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.round();
                                    if (index < 0 ||
                                        index >= report.daily.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        DateFormat('dd/MM')
                                            .format(report.daily[index].date),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineTouchData: LineTouchData(
                              touchCallback: (event, response) {
                                if (event is FlTapUpEvent &&
                                    response?.lineBarSpots?.isNotEmpty ==
                                        true) {
                                  final index = response!.lineBarSpots!.first.x
                                      .round();
                                  if (index >= 0 &&
                                      index < report.daily.length) {
                                    setState(
                                      () => _selectedDay =
                                          report.daily[index].date,
                                    );
                                  }
                                }
                              },
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                color: _turquoise,
                                barWidth: 3.5,
                                isStrokeCapRound: true,
                                isCurved: false,
                                spots: [
                                  for (var i = 0; i < report.daily.length; i++)
                                    report.daily[i].percentage == null
                                        ? FlSpot.nullSpot
                                        : FlSpot(
                                            i.toDouble(),
                                            report.daily[i].percentage!,
                                          ),
                                ],
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      _turquoise.withValues(alpha: .18),
                                      _turquoise.withValues(alpha: .01),
                                    ],
                                  ),
                                ),
                                dotData: const FlDotData(show: true),
                              ),
                            ],
                          ),
                          duration: Duration.zero,
                        ),
                      ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Voir les valeurs quotidiennes',
                        style: TextStyle(fontSize: 13),
                      ),
                      children: [
                        for (final day in report.daily)
                          ListTile(
                            dense: true,
                            title: Text(DateFormat('dd/MM').format(day.date)),
                            subtitle: Text(
                              '${day.confirmed}/${day.denominator} prises échues',
                            ),
                            trailing: Text(_rate(day.percentage)),
                            onTap: () =>
                                setState(() => _selectedDay = day.date),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _card(
                'Répartition des statuts',
                Column(
                  children: [
                    if (report.denominator > 0)
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 48,
                            sectionsSpace: 4,
                            sections: [
                              for (final status in AdherenceStatus.values.where(
                                (s) =>
                                    s != AdherenceStatus.future &&
                                    report.count(s) > 0,
                              ))
                                PieChartSectionData(
                                  value: report.count(status).toDouble(),
                                  title: '${report.count(status)}',
                                  color: _statusColor(status),
                                  radius: 34,
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          duration: Duration.zero,
                        ),
                      ),
                    for (final status in AdherenceStatus.values.where(
                      (s) => s != AdherenceStatus.future,
                    ))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: _statusColor(status),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(status.label)),
                            Text(
                              '${report.count(status)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _card(
                'Par médicament',
                Column(
                  children: [
                    if (report.medications.isEmpty)
                      const Text(
                        'Aucun médicament avec des prises enregistrées.',
                      ),
                    for (final m in report.medications)
                      ExpansionTile(
                        key: ValueKey('adherence-med-${m.id}'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(m.name),
                        subtitle: Text(
                          '${m.archived
                              ? 'Archivé · '
                              : m.completed
                              ? 'Terminé · '
                              : ''}${m.confirmed}/${m.denominator} · ${_rate(m.percentage)}',
                        ),
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final s in AdherenceStatus.values)
                                Chip(label: Text('${s.label} : ${m.count(s)}')),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _card(
                'Historique chronologique',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Du plus récent au plus ancien, selon l’horaire effectif. La confirmation est une déclaration enregistrée, pas une preuve de prise.',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    if (_selectedDay != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _selectedDay = null),
                        icon: const Icon(Icons.close),
                        label: Text(
                          'Effacer le filtre ${DateFormat('dd/MM').format(_selectedDay!)}',
                        ),
                      ),
                    if (history.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Aucune prise à afficher.'),
                      ),
                    for (final entry in history) _historyEntry(entry),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    ),
  );

  Widget _card(String title, Widget child) => MedicationSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6F2),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                switch (title) {
                  'Évolution quotidienne' => Icons.show_chart_rounded,
                  'Répartition des statuts' => Icons.donut_large_rounded,
                  'Par médicament' => Icons.medication_outlined,
                  'Historique chronologique' => Icons.history_rounded,
                  _ => Icons.insights_outlined,
                },
                size: 18,
                color: MedicationColors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: MedicationColors.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );

  Widget _historyEntry(AdherenceEntry entry) {
    final r = entry.record;
    final o = r.occurrence;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MedicationColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            o.medicationName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: MedicationColors.ink,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          MedicationBadge(
            label: entry.status.label,
            color: _statusColor(entry.status),
            icon: AdherenceStatusGrid.iconFor(entry.status),
          ),
          const SizedBox(height: 10),
          Text('Prévue : ${_date(r.plannedAt)}'),
          if (o.rescheduledDate != null)
            Text('Reportée au : ${_date(r.effectiveAt)}'),
          Text(
            o.confirmedAt == null
                ? 'Heure de confirmation : non renseignée'
                : 'Confirmée le : ${_date(o.confirmedAt!)}',
          ),
          if (entry.confirmedLate)
            const Text(
              'Confirmation tardive (≥ 60 min)',
              style: TextStyle(color: Color(0xFFD97706)),
            ),
          if (entry.postponedOverdue)
            const Text(
              'Report échu depuis au moins 60 min, toujours non confirmé.',
              style: TextStyle(color: Color(0xFFD97706)),
            ),
          if (entry.status == AdherenceStatus.future)
            Text(
              'Statut enregistré : ${o.statusLabel()} · hors taux avant échéance.',
            ),
          if (r.archivedAt != null)
            const Text('Traitement archivé', style: TextStyle(color: _muted)),
        ],
      ),
    );
  }
}
