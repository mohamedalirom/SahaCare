import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/services/medication_report_actions.dart';
import '../../data/services/medication_report_service.dart';
import '../../domain/entities/medication_report.dart';
import '../widgets/medication_scaffold.dart';
import '../widgets/medication_visuals.dart';
import '../widgets/report_pdf_preview.dart';

class MedicationReportScreen extends StatefulWidget {
  const MedicationReportScreen({
    super.key,
    this.service,
    this.actions,
    this.previewBuilder,
  });
  final MedicationReportService? service;
  final MedicationReportActions? actions;
  final Widget Function(Uint8List)? previewBuilder;
  @override
  State<MedicationReportScreen> createState() => _MedicationReportScreenState();
}

class _MedicationReportScreenState extends State<MedicationReportScreen> {
  late final MedicationReportService _service;
  late final MedicationReportActions _actions;
  late Future<List<ReportTreatment>> _choices;
  int _period = 7;
  int? _medicationId;
  late DateTimeRange _range;
  bool _completed = false,
      _adherence = true,
      _history = true,
      _symptoms = true,
      _acknowledge = false;
  bool _busy = false;
  int _generation = 0;
  String? _message;
  MedicationReportArtifact? _artifact;
  bool get _allowed {
    try {
      return _service.requireAccess().allowed;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MedicationReportService();
    _actions = widget.actions ?? MedicationReportActions();
    _relativeRange(7);
    _choices = _allowed ? _service.choices() : Future.value([]);
    if (widget.service == null) {
      _service.repository.access.addListener(_authChanged);
    }
  }

  @override
  void dispose() {
    if (widget.service == null) {
      _service.repository.access.removeListener(_authChanged);
    }
    super.dispose();
  }

  void _authChanged() {
    if (!mounted) return;
    setState(() {
      _generation++;
      _artifact = null;
      _busy = false;
      _acknowledge = false;
      _medicationId = null;
      _choices = _allowed ? _service.choices() : Future.value([]);
    });
  }

  void _relativeRange(int days) {
    final now = _service.clock().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(
      start: DateTime(today.year, today.month, today.day - days + 1),
      end: today,
    );
  }

  void _change(VoidCallback action) {
    setState(() {
      action();
      _artifact = null;
      _message = null;
      _generation++;
    });
  }

  Future<void> _customDates() async {
    final now = _service.clock().toLocal();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
      helpText: 'Période du rapport (366 jours maximum)',
    );
    if (range != null && mounted) {
      _change(() {
        _period = 0;
        _range = range;
      });
    }
  }

  Future<void> _generate() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _artifact = null;
      _message = null;
    });
    try {
      if (_period != 0) _relativeRange(_period);
      final artifact = await _service.generate(
        MedicationReportOptions(
          from: _range.start,
          through: _range.end,
          medicationId: _medicationId,
          includeCompleted: _completed,
          includeAdherence: _adherence,
          includeHistory: _history,
          includeSymptoms: _symptoms,
        ),
        acknowledgeAnonymous: _acknowledge,
      );
      if (mounted && generation == _generation) {
        setState(() => _artifact = artifact);
      }
    } on StateError catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _message = error.message.toString());
      }
    } on ArgumentError catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _message = error.message?.toString() ?? 'Période invalide.',
        );
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message = 'Le PDF n’a pas pu être généré. Aucune donnée n’a été modifiée. Réessayez avec une période plus courte.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _deliver({
    required bool share,
    required BuildContext buttonContext,
  }) async {
    final artifact = _artifact;
    if (artifact == null) return;
    final generation = _generation;
    try {
      _service.requireAccess(expectedKey: artifact.sessionKey);
      final box = buttonContext.findRenderObject() as RenderBox;
      final origin = box.localToGlobal(Offset.zero) & box.size;
      setState(() => _busy = true);
      final message = share
          ? switch (await _actions.share(artifact, origin: origin)) {
              ReportShareOutcome.dialogCompleted => 'Dialogue de partage terminé. Vérifiez auprès de l’application destinataire ; la réception n’est pas confirmée par SahaCare.',
              ReportShareOutcome.dismissed =>
                'Partage annulé. Aucun nouvel envoi demandé.',
              ReportShareOutcome.unavailable => 'Partage système indisponible ou résultat inconnu. Vous pouvez enregistrer le PDF pour le transmettre vous-même.',
            }
          : await _actions.save(artifact);
      _service.requireAccess(expectedKey: artifact.sessionKey);
      if (mounted && generation == _generation) {
        setState(() => _message = message);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message = 'Action indisponible ou interrompue. Aucun partage automatique n’est effectué. Vérifiez votre session et réessayez.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MedicationScaffold(
    manageNotifications: false,
    backgroundColor: MedicationColors.canvas,
    appBar: AppBar(
      title: const Text(
        'Mon rapport médical',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: MedicationColors.ink,
        ),
      ),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    body: FutureBuilder<List<ReportTreatment>>(
      future: _choices,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _choices = _service.choices()),
              child: const Text('Réessayer la lecture des traitements'),
            ),
          );
        }
        final treatments = snapshot.data ?? [];
        final allowed = _allowed;
        final filename = _artifact?.filename;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const MedicationSurface(
              gradient: LinearGradient(
                colors: [Color(0xFFE4F7F1), Color(0xFFEAF4FB)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    color: MedicationColors.teal,
                    size: 32,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Votre suivi, prêt à consulter.',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: MedicationColors.ink,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Créez un document A4 à partir des traitements et des prises enregistrés. Rien n’est partagé sans votre action.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: MedicationColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MedicationSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        allowed ? Icons.lock_outline : Icons.lock_rounded,
                        color: const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Confidentialité et identité',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: MedicationColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    allowed ? MedicationReportData.privacyNotice : 'Rapport indisponible : reconnectez-vous et vérifiez que la base Médicaments est prête. Aucun accès aux données d’un autre compte.',
                    key: const ValueKey('report-privacy'),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: MedicationColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MedicationSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personnaliser le rapport',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MedicationColors.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 jours')),
                      ButtonSegment(value: 30, label: Text('30 jours')),
                    ],
                    selected: _period == 0 ? <int>{} : {_period},
                    emptySelectionAllowed: true,
                    onSelectionChanged: allowed && !_busy
                        ? (values) {
                            if (values.isNotEmpty) {
                              _change(() {
                                _period = values.single;
                                _relativeRange(_period);
                              });
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('report-custom-period'),
                    onPressed: allowed && !_busy ? _customDates : null,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      _period == 0
                          ? 'Période personnalisée sélectionnée'
                          : 'Période personnalisée',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '${DateFormat('dd/MM/yyyy').format(_range.start)} - ${DateFormat('dd/MM/yyyy').format(_range.end)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: MedicationColors.muted,
                      ),
                    ),
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'report-medication-$_medicationId-${treatments.length}',
                    ),
                    initialValue: _medicationId ?? -1,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Médicament',
                      prefixIcon: Icon(Icons.medication_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('Tous les médicaments'),
                      ),
                      ...treatments.map(
                        (t) => DropdownMenuItem(
                          value: t.medication.id,
                          child: Text(
                            '${t.medication.name}${t.archivedAt != null
                                ? ' · Archivé'
                                : t.completedAt(_service.clock())
                                ? ' · Terminé'
                                : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: allowed && !_busy
                        ? (value) => _change(
                            () => _medicationId = value == -1 ? null : value,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _toggle(
                    'Inclure les traitements terminés ou archivés',
                    _completed,
                    (value) => _completed = value,
                    enabled: allowed,
                  ),
                  _toggle(
                    'Inclure les statistiques d’observance',
                    _adherence,
                    (value) => _adherence = value,
                    enabled: allowed,
                  ),
                  _toggle(
                    'Inclure l’historique des prises',
                    _history,
                    (value) => _history = value,
                    enabled: allowed,
                  ),
                  _toggle(
                    'Inclure la section symptômes disponibles',
                    _symptoms,
                    (value) => _symptoms = value,
                    enabled: allowed,
                  ),
                  const Text(
                    'Les descriptions de symptômes existent dans l’historique d’orientation, mais ne sont pas attribuées à un compte. Elles ne sont pas importées ; le PDF explique cette absence.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: MedicationColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                key: const ValueKey('report-anonymous-consent'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _acknowledge,
                onChanged: allowed && !_busy
                    ? (value) => _change(() => _acknowledge = value ?? false)
                    : null,
                title: const Text(
                  'J’ai vérifié les traitements locaux et j’accepte un rapport sans identité patient.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('report-generate'),
              onPressed: allowed && _acknowledge && !_busy ? _generate : null,
              style: FilledButton.styleFrom(
                backgroundColor: MedicationColors.teal,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Générer mon rapport'),
            ),
            if (allowed &&
                _artifact != null &&
                _service.sessionReader().key == _artifact!.sessionKey) ...[
              const SizedBox(height: 20),
              const Text(
                'Aperçu du PDF',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: MedicationColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vérifiez chaque page avant de partager. Si le lecteur intégré ne s’affiche pas, enregistrez le PDF pour l’ouvrir localement.',
                style: TextStyle(fontSize: 12, color: MedicationColors.muted),
              ),
              const SizedBox(height: 12),
              SizedBox(
                key: ValueKey('report-preview-$filename'),
                height: 480,
                child:
                    widget.previewBuilder?.call(_artifact!.bytes) ??
                    ReportPdfPreview(bytes: _artifact!.bytes),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  Builder(
                    builder: (buttonContext) => FilledButton.icon(
                      key: const ValueKey('report-share'),
                      onPressed: !_busy
                          ? () => _deliver(
                              share: true,
                              buttonContext: buttonContext,
                            )
                          : null,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Partager le rapport'),
                    ),
                  ),
                  Builder(
                    builder: (buttonContext) => OutlinedButton.icon(
                      key: const ValueKey('report-save'),
                      onPressed: !_busy
                          ? () => _deliver(
                              share: false,
                              buttonContext: buttonContext,
                            )
                          : null,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Enregistrer le PDF'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Chrome : téléchargement local et partage système selon les capacités du navigateur. Sur mobile : fichier dans les documents de l’application.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: MedicationColors.muted,
                ),
              ),
            ],
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _message!,
                    key: const ValueKey('report-message'),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: MedicationColors.ink,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    ),
  );
  Widget _toggle(
    String title,
    bool value,
    ValueChanged<bool> update, {
    required bool enabled,
  }) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: const TextStyle(fontSize: 13)),
    value: value,
    activeThumbColor: MedicationColors.teal,
    onChanged: enabled && !_busy
        ? (value) => _change(() => update(value))
        : null,
  );
}
