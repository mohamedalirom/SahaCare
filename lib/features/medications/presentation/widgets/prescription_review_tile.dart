import 'package:flutter/material.dart';

import '../../data/medication_catalog_repository.dart';
import '../../domain/entities/medication_suggestion.dart';
import '../../domain/entities/prescription_scan.dart';
import 'autocomplete_medication_field.dart';
import 'medication_visuals.dart';

class PrescriptionReviewTile extends StatefulWidget {
  const PrescriptionReviewTile({
    super.key,
    required this.candidate,
    required this.sessionKey,
    required this.catalog,
    required this.onChanged,
    this.enabled = true,
  });
  final PrescriptionCandidate candidate;
  final String sessionKey;
  final MedicationCatalogRepository catalog;
  final ValueChanged<PrescriptionDraft?> onChanged;
  final bool enabled;
  @override
  State<PrescriptionReviewTile> createState() => _PrescriptionReviewTileState();
}

class _PrescriptionReviewTileState extends State<PrescriptionReviewTile>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _dose, _times, _duration;
  MedicationSuggestion? _catalogChoice;
  String? _presentation;
  bool _accepted = false, _daily = false;
  @override
  void initState() {
    super.initState();
    final c = widget.candidate;
    _catalogChoice = c.exactName && !c.lowQuality && c.matches.length == 1
        ? c.matches.single
        : null;
    _name = TextEditingController(text: _catalogChoice?.name ?? '');
    _dose = TextEditingController(text: c.uncertain ? '' : c.strength ?? '');
    _times = TextEditingController(text: c.uncertain ? '' : c.times.join(', '));
    _duration = TextEditingController(
      text: c.uncertain ? '' : c.durationDays?.toString() ?? '',
    );
    _daily = !c.uncertain && c.daily;
    _name.addListener(_nameEdited);
  }

  @override
  void dispose() {
    for (final controller in [_name, _dose, _times, _duration]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _parsedTimes() => _times.text
      .split(RegExp(r'[,;\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  void _emit() {
    if (!_accepted || !_form.currentState!.validate()) {
      widget.onChanged(null);
      return;
    }
    final keepDates =
        !widget.candidate.uncertain &&
        _catalogChoice?.name == widget.candidate.matches.single.name;
    widget.onChanged(
      PrescriptionDraft(
        key: widget.candidate.key,
        sessionKey: widget.sessionKey,
        name: _name.text.trim(),
        activeIngredient: _catalogChoice?.activeIngredient,
        presentation: _presentation,
        dosage: _dose.text.trim(),
        times: _parsedTimes(),
        durationDays: int.tryParse(_duration.text),
        weekdaysMask: _daily ? 127 : 0,
        startDate: keepDates ? widget.candidate.startDate : null,
        endDate: keepDates ? widget.candidate.endDate : null,
      ),
    );
  }

  void _nameEdited() {
    if (!mounted) return;
    setState(() {
      _accepted = false;
      if (_catalogChoice != null &&
          _name.text.trim().toLowerCase() !=
              _catalogChoice!.name.toLowerCase()) {
        _catalogChoice = null;
        _presentation = null;
        _dose.clear();
        _times.clear();
        _duration.clear();
        _daily = false;
      }
    });
    widget.onChanged(null);
  }

  void _choose(MedicationSuggestion choice) {
    final different =
        _catalogChoice?.name.toLowerCase() != choice.name.toLowerCase();
    setState(() {
      _name.text = choice.name;
      _catalogChoice = choice;
      _presentation = null;
      _accepted = false;
      if (different) {
        _dose.clear();
        _times.clear();
        _duration.clear();
        _daily = false;
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = widget.candidate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MedicationSurface(
        child: IgnorePointer(
          ignoring: !widget.enabled,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.line == 0
                      ? 'Sélection manuelle'
                      : 'Suggestion · ligne ${c.line}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: MedicationColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                MedicationBadge(
                  label: c.lowQuality
                      ? 'Qualité OCR faible : sélection explicite requise'
                      : c.uncertain
                      ? 'Correspondance incertaine : choisissez le médicament'
                      : 'Nom repéré dans le catalogue local',
                  color: c.uncertain
                      ? const Color(0xFFB45309)
                      : MedicationColors.teal,
                  icon: Icons.fact_check_outlined,
                ),
                if (c.repeated)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Nom déjà repéré sur une autre ligne : vérifiez les doublons.',
                      style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                SelectableText(
                  c.sourceText,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: MedicationColors.muted,
                  ),
                ),
                if (c.matches.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Correspondances possibles : ${c.matches.map((m) => m.name).join(', ')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: MedicationColors.muted,
                    ),
                  ),
                ],
                if (c.evidence.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final match in c.evidence)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.explanation,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  match.level ==
                                      PrescriptionMatchLevel.tentative
                                  ? const Color(0xFFB45309)
                                  : MedicationColors.muted,
                            ),
                          ),
                          ActionChip(
                            label: Text(match.medication.name),
                            onPressed: widget.enabled
                                ? () => _choose(match.medication)
                                : null,
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                AutocompleteMedicationField(
                  controller: _name,
                  catalogRepository: widget.catalog,
                  localOnly: true,
                  onSuggestionSelected: _choose,
                  onSuggestionCleared: () {
                    setState(() {
                      _catalogChoice = null;
                      _presentation = null;
                      _accepted = false;
                    });
                    _emit();
                  },
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Choisissez ou corrigez le nom.'
                      : null,
                ),
                if (_catalogChoice?.activeIngredient != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Substance active (catalogue) : ${_catalogChoice!.activeIngredient}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MedicationColors.muted,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_catalogChoice?.presentations.isNotEmpty == true)
                  DropdownButtonFormField<String>(
                    key: ValueKey('scan-presentation-${_catalogChoice!.name}'),
                    initialValue: _presentation,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Présentation à choisir (catalogue)',
                    ),
                    items: _catalogChoice!.presentations
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(p, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _presentation = value);
                      _emit();
                    },
                  )
                else
                  const Text(
                    'Présentation non choisie ou non disponible.',
                    style: TextStyle(
                      fontSize: 12,
                      color: MedicationColors.muted,
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey('scan-dose-${c.key}'),
                  controller: _dose,
                  decoration: const InputDecoration(
                    labelText: 'Dosage explicite à vérifier',
                    hintText: 'Laisser vide si non lisible',
                  ),
                  onChanged: (_) => _emit(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey('scan-times-${c.key}'),
                  controller: _times,
                  decoration: const InputDecoration(
                    labelText: 'Horaires explicites (HH:mm, HH:mm)',
                    hintText: 'Aucun horaire déduit d’une fréquence',
                  ),
                  onChanged: (_) => _emit(),
                  validator: (_) {
                    final times = _parsedTimes();
                    if (times.any(
                      (t) =>
                          !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(t),
                    )) {
                      return 'Utilisez des horaires HH:mm valides.';
                    }
                    if (times.toSet().length != times.length) {
                      return 'Un horaire est répété.';
                    }
                    return null;
                  },
                ),
                if (c.frequency != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Fréquence écrite : ${c.frequency}. Les heures restent à choisir.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MedicationColors.muted,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey('scan-duration-${c.key}'),
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durée explicite en jours (facultatif)',
                  ),
                  onChanged: (_) => _emit(),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? null
                      : int.tryParse(value) == null || int.parse(value) <= 0
                      ? 'Saisissez un nombre de jours positif.'
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _daily,
                  onChanged: (value) {
                    setState(() => _daily = value);
                    _emit();
                  },
                  title: const Text(
                    'Tous les jours',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'À confirmer selon l’ordonnance ; sinon choisissez les jours dans le formulaire.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                CheckboxListTile(
                  key: ValueKey('scan-accept-${c.key}'),
                  contentPadding: EdgeInsets.zero,
                  value: _accepted,
                  onChanged: (value) {
                    setState(() => _accepted = value ?? false);
                    _emit();
                  },
                  title: const Text(
                    'Accepter cette suggestion pour la vérifier dans le formulaire',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                if (!widget.enabled)
                  const Text(
                    'Import indisponible pour cette session.',
                    style: TextStyle(
                      fontSize: 12,
                      color: MedicationColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
