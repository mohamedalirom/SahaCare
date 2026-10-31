import '../widgets/medication_scaffold.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../data/medication_repository.dart';
import '../../domain/entities/medication_occurrence.dart';
import '../../domain/entities/medication_stock.dart';
import '../widgets/medication_calendar_widgets.dart';

enum _CalendarView { day, week, month }

const _monthNames = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

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

  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  _CalendarView _view = _CalendarView.month;
  List<MedicationOccurrence> _occurrences = const [];
  bool _loading = true;
  Object? _loadError;
  final Set<int> _busyOccurrenceIds = {};
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadPeriod();
  }

  DateTime get _periodStart {
    return switch (_view) {
      _CalendarView.day => _selectedDate,
      _CalendarView.week => _selectedDate.subtract(
        Duration(days: _selectedDate.weekday - 1),
      ),
      _CalendarView.month => DateTime(_selectedDate.year, _selectedDate.month),
    };
  }

  DateTime get _periodEnd {
    return switch (_view) {
      _CalendarView.day => _selectedDate,
      _CalendarView.week => _periodStart.add(const Duration(days: 6)),
      _CalendarView.month => DateTime(
        _selectedDate.year,
        _selectedDate.month + 1,
        0,
      ),
    };
  }

  Future<void> _loadPeriod() async {
    final request = ++_loadRequest;
    final start = _periodStart;
    final end = _periodEnd;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      await _repository.ensureOccurrences(from: start, through: end);
      final occurrences = await _repository.getOccurrences(
        from: start,
        through: end,
      );
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _occurrences = occurrences;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  void _movePeriod(int amount) {
    setState(() {
      _selectedDate = switch (_view) {
        _CalendarView.day => _selectedDate.add(Duration(days: amount)),
        _CalendarView.week => _selectedDate.add(Duration(days: amount * 7)),
        _CalendarView.month => _shiftMonth(_selectedDate, amount),
      };
    });
    _loadPeriod();
  }

  DateTime _shiftMonth(DateTime date, int amount) {
    final month = DateTime(date.year, date.month + amount);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(
      month.year,
      month.month,
      date.day.clamp(1, lastDay).toInt(),
    );
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = DateUtils.dateOnly(date));
  }

  Future<void> _openMedication(int medicationId) async {
    await context.push<bool>('/medications/detail?id=$medicationId');
    if (mounted) _loadPeriod();
  }

  Future<void> _updateOccurrence(
    MedicationOccurrence occurrence,
    Future<void> Function() update,
  ) async {
    setState(() => _busyOccurrenceIds.add(occurrence.id));
    try {
      await update();
      final medication = await _repository.getById(occurrence.medicationId);
      final stock = medication?.stock;
      if (mounted &&
          stock != null &&
          stock.enabled &&
          stock.alert != StockAlert.normal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              stock.pendingAnomalies > 0
                  ? 'Une prise a été confirmée sans débit complet du stock. Une anomalie reste à régulariser sur la fiche du médicament.'
                  : 'Stock faible : ${stock.remaining.display} ${stock.unit.label}. Consultez la fiche du médicament.',
            ),
            backgroundColor: stock.pendingAnomalies > 0
                ? const Color(0xFFDC2626)
                : const Color(0xFFD97706),
          ),
        );
      }
      if (mounted) {
        setState(() => _busyOccurrenceIds.remove(occurrence.id));
      }
      if (!mounted) return;
      await _loadPeriod();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de mettre à jour la prise : $error'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _busyOccurrenceIds.remove(occurrence.id));
    }
  }

  Future<void> _postponeOccurrence(MedicationOccurrence occurrence) async {
    final startDate = DateUtils.dateOnly(occurrence.medicationStartDate);
    final endDate = occurrence.medicationEndDate ?? DateTime(2100, 12, 31);
    final initialDate = occurrence.effectiveDate.isBefore(startDate)
        ? startDate
        : occurrence.effectiveDate.isAfter(endDate)
        ? endDate
        : occurrence.effectiveDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: startDate,
      lastDate: endDate,
      helpText: 'Choisir la date de report',
    );
    if (date == null || !mounted) return;
    final parts = occurrence.effectiveTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Choisir l’heure de report',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    final formattedTime =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    await _updateOccurrence(
      occurrence,
      () => _repository.postponeOccurrence(
        occurrenceId: occurrence.id,
        date: date,
        time: formattedTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MedicationScaffold(
    manageNotifications: widget.repository == null,
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Calendrier thérapeutique',
        style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
    ),
    body: _loadError != null
        ? _loadErrorState()
        : _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 112),
            children: [
              _introCard(),
              const SizedBox(height: 16),
              _viewSelector(),
              const SizedBox(height: 14),
              _periodNavigation(),
              const SizedBox(height: 10),
              if (_view == _CalendarView.week) _weekSelector(),
              if (_view == _CalendarView.month) _monthCalendar(),
              const SizedBox(height: 22),
              _dailyHeading(),
              const SizedBox(height: 12),
              _dailySchedule(),
            ],
          ),
  );

  Widget _introCard() => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0D9488).withValues(alpha: 0.14),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Votre planning de prises',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Consultez et suivez vos traitements',
                style: TextStyle(color: Color(0xFFD9F6F1), fontSize: 12),
              ),
            ],
          ),
        ),
        if (SupabaseConfig.isDemoMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'DÉMO LOCALE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _loadErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Impossible de charger le calendrier thérapeutique.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFB91C1C)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadPeriod,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );

  Widget _viewSelector() => SegmentedButton<_CalendarView>(
    segments: const [
      ButtonSegment(
        value: _CalendarView.day,
        icon: Icon(Icons.view_day_outlined),
        label: Text('Jour'),
      ),
      ButtonSegment(
        value: _CalendarView.week,
        icon: Icon(Icons.view_week_outlined),
        label: Text('Semaine'),
      ),
      ButtonSegment(
        value: _CalendarView.month,
        icon: Icon(Icons.calendar_month_outlined),
        label: Text('Mois'),
      ),
    ],
    selected: {_view},
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFF0D9488)
            : Colors.white,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : const Color(0xFF475569),
      ),
      side: WidgetStateProperty.all(const BorderSide(color: Color(0xFFE2E8F0))),
    ),
    onSelectionChanged: (selection) {
      setState(() => _view = selection.first);
      _loadPeriod();
    },
  );

  Widget _periodNavigation() {
    final title = switch (_view) {
      _CalendarView.day => _formatDate(_selectedDate),
      _CalendarView.week =>
        '${_formatDate(_periodStart)} – ${_formatDate(_periodEnd)}',
      _CalendarView.month =>
        '${_monthNames[_selectedDate.month - 1]} ${_selectedDate.year}',
    };
    return Row(
      children: [
        IconButton(
          tooltip: 'Période précédente',
          onPressed: () => _movePeriod(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Période suivante',
          onPressed: () => _movePeriod(1),
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          tooltip: 'Aujourd’hui',
          onPressed: () {
            setState(() => _selectedDate = DateUtils.dateOnly(DateTime.now()));
            _loadPeriod();
          },
          icon: const Icon(Icons.today_outlined, color: Color(0xFF0D9488)),
        ),
      ],
    );
  }

  Widget _weekSelector() {
    return MedicationWeekSelector(
      weekStart: _periodStart,
      selectedDate: _selectedDate,
      occurrences: _occurrences,
      onSelected: _selectDate,
    );
  }

  Widget _monthCalendar() {
    return MedicationMonthCalendar(
      month: _selectedDate,
      selectedDate: _selectedDate,
      occurrences: _occurrences,
      onSelected: _selectDate,
    );
  }

  Widget _dailyHeading() {
    final count = _countForDate(_selectedDate);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Planning du ${_selectedDate.day.toString().padLeft(2, '0')}/'
            '${_selectedDate.month.toString().padLeft(2, '0')}/'
            '${_selectedDate.year}',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F7F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count prise${count == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Color(0xFF0D9488),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dailySchedule() {
    final dayOccurrences =
        _occurrences
            .where(
              (occurrence) =>
                  DateUtils.isSameDay(occurrence.effectiveDate, _selectedDate),
            )
            .toList()
          ..sort((first, second) {
            final timeOrder = first.effectiveTime.compareTo(
              second.effectiveTime,
            );
            return timeOrder != 0
                ? timeOrder
                : first.medicationName.compareTo(second.medicationName);
          });
    return MedicationDailyTimeline(
      occurrences: dayOccurrences,
      busyOccurrenceIds: _busyOccurrenceIds,
      onOpen: _openMedication,
      onTaken: (occurrence) => _updateOccurrence(
        occurrence,
        () => _repository.markOccurrenceTaken(occurrence.id),
      ),
      onPostpone: _postponeOccurrence,
      onIgnore: (occurrence) => _updateOccurrence(
        occurrence,
        () => _repository.ignoreOccurrence(occurrence.id),
      ),
    );
  }

  int _countForDate(DateTime date) => _occurrences
      .where(
        (occurrence) => DateUtils.isSameDay(occurrence.effectiveDate, date),
      )
      .length;

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
