import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/medical_history.dart';
import '../providers/profile_providers.dart';
import '../widgets/add_medical_record_sheet.dart';
import '../widgets/animated_record_list.dart';
import '../widgets/medical_speed_dial.dart';
import '../extensions/profile_enum_extensions.dart';
import '../../../../i18n/strings.g.dart';
import 'package:intl/intl.dart';

enum _DatePeriod {
  lastYear('12 derniers mois'),
  lastFiveYears('5 dernières années'),
  older('Plus ancien');

  const _DatePeriod(this.label);
  final String label;

  String get localized => switch (this) {
        _DatePeriod.lastYear => t.last12Months,
        _DatePeriod.lastFiveYears => t.last5Years,
        _DatePeriod.older => t.older,
      };

  bool matches(DateTime? date, DateTime now) {
    if (date == null) return false;
    final oneYear = DateTime(now.year - 1, now.month, now.day);
    final fiveYears = DateTime(now.year - 5, now.month, now.day);
    return switch (this) {
      _DatePeriod.lastYear => !date.isBefore(oneYear),
      _DatePeriod.lastFiveYears => !date.isBefore(fiveYears),
      _DatePeriod.older => date.isBefore(fiveYears),
    };
  }
}

enum _DiseaseNature { chronic, acute }

/// Dossier médical — CRUD complet (offline-first, via l'outbox).
class MedicalRecordsScreen extends ConsumerStatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  ConsumerState<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends ConsumerState<MedicalRecordsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)..addListener(_onTab);
  final ValueNotifier<bool> _dialOpen = ValueNotifier(false);

  // Filters
  _DiseaseNature? _nature;
  _DatePeriod? _period;
  final Set<AllergySeverity> _severities = {};
  final Set<AllergyKind> _kinds = {};

  /// Ids swiped away and waiting for the "Undo" window to elapse.
  final Set<String> _pendingDeletes = {};

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTab)
      ..dispose();
    _dialOpen.dispose();
    super.dispose();
  }

  void _onTab() {
    if (_tabs.indexIsChanging) return;
    _dialOpen.value = false;
    setState(() {});
  }

  bool get _hasActiveFilters => switch (_tabs.index) {
        0 => _nature != null || _period != null,
        1 => _severities.isNotEmpty || _kinds.isNotEmpty,
        _ => _period != null,
      };

  void _resetFilters() => setState(() {
        _nature = null;
        _period = null;
        _severities.clear();
        _kinds.clear();
      });

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<void> _openSheet(MedicalRecordType type, {Object? existing}) async {
    _dialOpen.value = false;
    await AddMedicalRecordSheet.show(context, type, existing: existing);
  }

  /// Hides the row immediately and only commits the deletion once the
  /// SnackBar closes WITHOUT the user pressing "Annuler".
  Future<void> _deleteWithUndo({
    required String id,
    required String label,
    required Future<void> Function() commit,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pendingDeletes.add(id));

    messenger.hideCurrentSnackBar(); // closing it commits the previous delete
    final controller = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Text('« $label » supprimé'),
        action: SnackBarAction(label: 'Annuler', onPressed: () {}),
      ),
    );

    final reason = await controller.closed;
    if (reason == SnackBarClosedReason.action) {
      if (mounted) setState(() => _pendingDeletes.remove(id));
      return;
    }
    try {
      await commit();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Suppression impossible.')));
    } finally {
      if (mounted) setState(() => _pendingDeletes.remove(id));
    }
  }

  // ---------------------------------------------------------------------------
  // Filtering / sorting
  // ---------------------------------------------------------------------------

  List<Disease> _diseases(List<Disease> all) {
    final now = DateTime.now();
    final list = all.where((d) {
      if (_pendingDeletes.contains(d.id)) return false;
      if (_nature == _DiseaseNature.chronic && !d.isChronic) return false;
      if (_nature == _DiseaseNature.acute && d.isChronic) return false;
      if (_period != null && !_period!.matches(d.diagnosedAt, now)) return false;
      return true;
    }).toList();
    list.sort((a, b) => (b.diagnosedAt ?? DateTime(0)).compareTo(a.diagnosedAt ?? DateTime(0)));
    return list;
  }

  List<Allergy> _allergies(List<Allergy> all) {
    final list = all.where((a) {
      if (_pendingDeletes.contains(a.id)) return false;
      if (_severities.isNotEmpty && !_severities.contains(a.severity)) return false;
      if (_kinds.isNotEmpty && !_kinds.contains(a.kind)) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      final bySeverity = b.severity.index.compareTo(a.severity.index);
      return bySeverity != 0 ? bySeverity : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  List<MedicalHistoryEntry> _history(List<MedicalHistoryEntry> all) {
    final now = DateTime.now();
    final list = all.where((e) {
      if (_pendingDeletes.contains(e.id)) return false;
      if (_period != null && !_period!.matches(e.date, now)) return false;
      return true;
    }).toList();
    list.sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    return list;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(medicalHistoryProvider);
    final notifier = ref.read(medicalHistoryProvider.notifier);

    // Local messenger so SnackBars sit above the speed dial, not under it.
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: MedicalSpeedDial(open: _dialOpen, onSelected: _openSheet),
        body: Column(
          children: [
            // Sticky header: tabs + dynamic filter chips.
            Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              elevation: 1,
              child: Column(
                children: [
                  TabBar(
                    controller: _tabs,
                    tabs: [
                      Tab(text: t.diseases),
                      Tab(text: t.allergies),
                      Tab(text: t.history),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey(_tabs.index),
                        child: _FilterBar(
                          chips: _chipsForTab(),
                          showReset: _hasActiveFilters,
                          onReset: _resetFilters,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  historyAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _ErrorView(onRetry: () => ref.invalidate(medicalHistoryProvider)),
                    data: (history) => TabBarView(
                      controller: _tabs,
                      children: [
                        _TabBody(
                          isEmpty: _diseases(history.diseases).isEmpty,
                          filtered: history.diseases.isNotEmpty,
                          emptyLabel: 'Aucune maladie enregistrée.',
                          onRefresh: () => ref.refresh(medicalHistoryProvider.future),
                          child: AnimatedRecordList<Disease>(
                            items: _diseases(history.diseases),
                            idOf: (d) => d.id,
                            onDismissed: (d) => _deleteWithUndo(
                              id: d.id,
                              label: d.name,
                              commit: () => notifier.deleteDisease(d.id),
                            ),
                            itemBuilder: (_, d) {
                              final formattedDate = d.diagnosedAt == null
                                  ? null
                                  : DateFormat.yMMMM(LocaleSettings.currentLocale.languageCode).format(d.diagnosedAt!);
                              return _RecordCard(
                                color: d.isChronic ? const Color(0xFFF97316) : MedicalRecordType.disease.color,
                                icon: MedicalRecordType.disease.icon,
                                title: d.name,
                                subtitle: formattedDate == null
                                    ? t.unknownDate
                                    : t.diagnosedIn(date: formattedDate),
                                badge: d.isChronic ? t.chronic : null,
                                onTap: () => _openSheet(MedicalRecordType.disease, existing: d),
                              );
                            },
                          ),
                        ),
                        _TabBody(
                          isEmpty: _allergies(history.allergies).isEmpty,
                          filtered: history.allergies.isNotEmpty,
                          emptyLabel: 'Aucune allergie enregistrée.',
                          onRefresh: () => ref.refresh(medicalHistoryProvider.future),
                          child: AnimatedRecordList<Allergy>(
                            items: _allergies(history.allergies),
                            idOf: (a) => a.id,
                            onDismissed: (a) => _deleteWithUndo(
                              id: a.id,
                              label: a.name,
                              commit: () => notifier.deleteAllergy(a.id),
                            ),
                            itemBuilder: (_, a) => _RecordCard(
                              color: severityColor(a.severity),
                              icon: allergyKindIcon(a.kind),
                              title: a.name,
                              subtitle: a.kind.localized,
                              badge: a.severity.localized,
                              onTap: () => _openSheet(MedicalRecordType.allergy, existing: a),
                            ),
                          ),
                        ),
                        _TabBody(
                          isEmpty: _history(history.history).isEmpty,
                          filtered: history.history.isNotEmpty,
                          emptyLabel: 'Aucun antécédent enregistré.',
                          onRefresh: () => ref.refresh(medicalHistoryProvider.future),
                          child: AnimatedRecordList<MedicalHistoryEntry>(
                            items: _history(history.history),
                            idOf: (e) => e.id,
                            onDismissed: (e) => _deleteWithUndo(
                              id: e.id,
                              label: e.title,
                              commit: () => notifier.deleteHistoryEntry(e.id),
                            ),
                            itemBuilder: (_, e) {
                              final formattedDate = e.date == null
                                  ? null
                                  : DateFormat.yMMMM(LocaleSettings.currentLocale.languageCode).format(e.date!);
                              return _RecordCard(
                                color: MedicalRecordType.history.color,
                                icon: MedicalRecordType.history.icon,
                                title: e.title,
                                subtitle: [
                                  ?formattedDate,
                                  if (e.description.isNotEmpty) e.description,
                                ].join(' · '),
                                onTap: () => _openSheet(MedicalRecordType.history, existing: e),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrim behind the expanded speed dial.
                  ValueListenableBuilder<bool>(
                    valueListenable: _dialOpen,
                    builder: (_, open, _) => IgnorePointer(
                      ignoring: !open,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _dialOpen.value = false,
                        child: AnimatedOpacity(
                          opacity: open ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: ColoredBox(color: Colors.black.withValues(alpha: 0.35), child: const SizedBox.expand()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter chips
  // ---------------------------------------------------------------------------

  List<Widget> _chipsForTab() {
    Widget chip(String label, bool selected, VoidCallback onTap, {Color? color}) => _FilterChipItem(
          label: label,
          selected: selected,
          color: color,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
        );

    List<Widget> dateChips() => [
          for (final p in _DatePeriod.values)
            chip(p.localized, _period == p, () => setState(() => _period = _period == p ? null : p)),
        ];

    switch (_tabs.index) {
      case 0:
        return [
          chip(t.chronic, _nature == _DiseaseNature.chronic,
              () => setState(() => _nature = _nature == _DiseaseNature.chronic ? null : _DiseaseNature.chronic)),
          chip(t.acute, _nature == _DiseaseNature.acute,
              () => setState(() => _nature = _nature == _DiseaseNature.acute ? null : _DiseaseNature.acute)),
          ...dateChips(),
        ];
      case 1:
        return [
          for (final s in AllergySeverity.values)
            chip(s.localized, _severities.contains(s), () => setState(() {
                  if (!_severities.remove(s)) _severities.add(s);
                }), color: severityColor(s)),
          for (final k in AllergyKind.values)
            chip(k.localized, _kinds.contains(k), () => setState(() {
                  if (!_kinds.remove(k)) _kinds.add(k);
                })),
        ];
      default:
        return dateChips();
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.chips, required this.showReset, required this.onReset});

  final List<Widget> chips;
  final bool showReset;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          if (showReset)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: Text(t.reset),
                onPressed: onReset,
              ),
            ),
          for (final c in chips) Padding(padding: const EdgeInsets.only(right: 8), child: c),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({required this.label, required this.selected, required this.onTap, this.color});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: color?.withValues(alpha: 0.2),
      checkmarkColor: color,
      onSelected: (_) => onTap(),
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.isEmpty,
    required this.filtered,
    required this.emptyLabel,
    required this.child,
    required this.onRefresh,
  });

  final bool isEmpty;

  /// True when records exist but the active filters hide them all.
  final bool filtered;
  final String emptyLabel;
  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: isEmpty ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          filtered ? Icons.filter_list_off_rounded : Icons.folder_open_rounded,
                          size: 56,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          filtered ? 'Aucun résultat pour ces filtres.' : emptyLabel,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (!filtered) ...[
                          const SizedBox(height: 4),
                          Text('Touchez + pour ajouter.', style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                  child: Text(badge!, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            const Text('Impossible de charger le dossier médical.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
