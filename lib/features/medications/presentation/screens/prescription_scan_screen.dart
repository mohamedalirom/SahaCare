import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/medication_access.dart';
import '../../data/medication_catalog_repository.dart';
import '../../data/medication_repository.dart';
import '../../data/services/prescription_image_service.dart';
import '../../data/services/prescription_image_processing.dart';
import '../../data/services/prescription_ocr_backend.dart';
import '../../data/services/prescription_ocr_factory.dart';
import '../../data/services/prescription_scan_session.dart';
import '../../domain/entities/prescription_scan.dart';
import '../../domain/services/prescription_extractor.dart';
import '../widgets/medication_scaffold.dart';
import '../widgets/medication_visuals.dart';
import '../widgets/prescription_review_tile.dart';
import 'medication_form_screen.dart';

class PrescriptionScanScreen extends StatefulWidget {
  const PrescriptionScanScreen({
    super.key,
    this.ocr,
    this.images,
    this.catalog,
    this.repository,
    this.sessionReader,
  });
  final PrescriptionOcrBackend? ocr;
  final PrescriptionImageService? images;
  final MedicationCatalogRepository? catalog;
  final MedicationRepository? repository;
  final PrescriptionScanSession Function()? sessionReader;
  @override
  State<PrescriptionScanScreen> createState() => _PrescriptionScanScreenState();
}

class _PrescriptionScanScreenState extends State<PrescriptionScanScreen>
    with WidgetsBindingObserver {
  late final PrescriptionOcrBackend _ocr;
  late final PrescriptionImageService _images;
  late final MedicationCatalogRepository _catalog;
  final _corrected = TextEditingController();
  final _accepted = <String, PrescriptionDraft>{};
  final _saved = <String>{};
  PrescriptionImage? _image, _original;
  PrescriptionImage? _enhanced;
  PrescriptionImageMode _imageMode = PrescriptionImageMode.original;
  PrescriptionImage? get _preview => _enhanced ?? _image;
  int _manualSequence = 0;
  PrescriptionOcrResult? _result;
  List<PrescriptionCandidate> _candidates = [];
  bool _busy = false, _importing = false;
  double? _progress;
  int _generation = 0, _reviewVersion = 0;
  String? _message;
  BuildContext? _cropContext;
  late String _sessionKey;
  PrescriptionScanSession get _session =>
      (widget.sessionReader ?? PrescriptionScanSession.current)();
  bool get _valid => _session.canImport && _session.key == _sessionKey;
  bool get _cameraSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  void initState() {
    super.initState();
    _ocr = widget.ocr ?? createPrescriptionOcrBackend();
    _images = widget.images ?? PrescriptionImageService();
    _catalog = widget.catalog ?? DefaultMedicationCatalogRepository();
    _sessionKey = _session.key;
    WidgetsBinding.instance.addObserver(this);
    if (widget.sessionReader == null) {
      MedicationAccess.instance.addListener(_authChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.sessionReader == null) {
      MedicationAccess.instance.removeListener(_authChanged);
    }
    unawaited(_ocr.cancel());
    _corrected.dispose();
    if (widget.catalog == null) {
      (_catalog as DefaultMedicationCatalogRepository).close();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) _clear();
  }

  void _authChanged() {
    if (mounted) {
      _clear();
      setState(() => _sessionKey = _session.key);
    }
  }

  void _clear() {
    _generation++;
    unawaited(_ocr.cancel());
    final cropContext = _cropContext;
    if (cropContext != null &&
        cropContext.mounted &&
        ModalRoute.of(cropContext)?.isCurrent == true) {
      Navigator.of(cropContext).pop(false);
    }
    for (final image in [_image, _original, _enhanced]) {
      if (image != null) unawaited(MemoryImage(image.bytes).evict());
    }
    if (!mounted) return;
    setState(() {
      _image = null;
      _enhanced = null;
      _imageMode = PrescriptionImageMode.original;
      _original = null;
      _result = null;
      _corrected.clear();
      _candidates = [];
      _accepted.clear();
      _saved.clear();
      _busy = false;
      _progress = null;
      _message = null;
      _reviewVersion++;
    });
  }

  Future<void> _pick(bool camera) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final image = await _images.pick(camera: camera);
      if (!mounted || generation != _generation) return;
      if (image != null) {
        setState(() {
          _image = image;
          _enhanced = null;
          _imageMode = PrescriptionImageMode.original;
          _original = image;
          _result = null;
          _corrected.clear();
          _candidates = [];
          _accepted.clear();
          _saved.clear();
          _reviewVersion++;
        });
      }
    } on FormatException catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _message = error.message);
      }
    } on PlatformException catch (error) {
      if (mounted && generation == _generation) {
        final denied =
            error.code == 'camera_access_denied' ||
            error.code == 'photo_access_denied' ||
            error.code == 'camera_access_restricted' ||
            error.code == 'photo_access_restricted';
        setState(() {
          _message = denied
              ? 'Accès ${camera ? 'à la caméra' : 'aux photos'} refusé ou restreint. '
                    'Vérifiez les autorisations de SahaCare dans les réglages du téléphone, '
                    'ou choisissez une autre source. Aucune analyse n’a été lancée.'
              : 'Impossible d’ouvrir ${camera ? 'la caméra' : 'la galerie'}. '
                    'Réessayez ou choisissez une autre source.';
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message = 'Import ou permission indisponible. Choisissez une image JPG/PNG ou vérifiez les autorisations de la caméra.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _transform(Future<PrescriptionImage> Function() action) async {
    final generation = ++_generation;
    setState(() => _busy = true);
    try {
      final image = await action();
      if (mounted && generation == _generation) {
        setState(() {
          _image = image;
          _enhanced = null;
          _imageMode = PrescriptionImageMode.original;
          _result = null;
          _corrected.clear();
          _candidates = [];
          _accepted.clear();
          _saved.clear();
          _reviewVersion++;
          _message = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message = 'Transformation impossible. Choisissez une zone plus grande ou une autre photo.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _crop() async {
    if (_image == null) return;
    final image = _image!;
    final generation = _generation;
    var horizontal = const RangeValues(0, 100),
        vertical = const RangeValues(0, 100);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        _cropContext = context;
        return StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Recadrer l’ordonnance'),
            content: _image == null
                ? const Text('Scan effacé.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 200,
                          child: AspectRatio(
                            aspectRatio: image.width / image.height,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(image.bytes, fit: BoxFit.fill),
                                CustomPaint(
                                  painter: _CropOverlay(horizontal, vertical),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Limites gauche / droite'),
                        RangeSlider(
                          values: horizontal,
                          max: 100,
                          divisions: 100,
                          onChanged: (value) =>
                              update(() => horizontal = value),
                        ),
                        const Text('Limites haut / bas'),
                        RangeSlider(
                          values: vertical,
                          max: 100,
                          divisions: 100,
                          onChanged: (value) => update(() => vertical = value),
                        ),
                      ],
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Recadrer'),
              ),
            ],
          ),
        );
      },
    );
    _cropContext = null;
    if (accepted == true &&
        mounted &&
        _image != null &&
        generation == _generation) {
      await _transform(
        () => _images.crop(
          _image!,
          left: horizontal.start / 100,
          top: vertical.start / 100,
          right: horizontal.end / 100,
          bottom: vertical.end / 100,
        ),
      );
    }
  }

  Future<void> _enhance(PrescriptionImageMode mode) async {
    if (_image == null) return;
    final generation = ++_generation;
    setState(() => _busy = true);
    try {
      final image = await _images.enhance(_image!, mode);
      if (!mounted || generation != _generation) return;
      setState(() {
        _enhanced = mode == PrescriptionImageMode.original ? null : image;
        _imageMode = mode;
        _result = null;
        _corrected.clear();
        _accepted.clear();
        _candidates = [];
        _saved.clear();
        _reviewVersion++;
        _message = null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message = 'Amélioration locale indisponible. L’image précédente est conservée.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  void _addManual() {
    setState(
      () => _candidates = [
        ..._candidates,
        PrescriptionCandidate(
          key: 'manual-${++_manualSequence}',
          line: 0,
          sourceText: 'Sélection manuelle dans le catalogue local. Aucun résultat OCR validé.',
          matches: const [],
          exactName: false,
        ),
      ],
    );
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _message = null;
      _progress = 0;
      _accepted.clear();
      _candidates = [];
      _result = null;
      _corrected.clear();
      _saved.clear();
      _reviewVersion++;
    });
    try {
      final result = await _ocr.recognize(
        _preview!.bytes,
        onProgress: (value) {
          if (mounted && generation == _generation) {
            setState(() => _progress = value.clamp(0, 1));
          }
        },
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = result;
        _corrected.text = result.text;
      });
      await _extract(generation);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message = 'L’OCR local n’a pas pu aboutir. Reprenez une photo nette, recadrez ou corrigez le texte manuellement. Aucune fausse analyse n’est affichée.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _extract(int generation) async {
    final catalog = await _catalog.searchLocal('');
    final candidates = PrescriptionExtractor().extract(
      _corrected.text,
      catalog,
      allowExplicitFields:
          _result?.confidence == null || _result!.confidence! >= 60,
    );
    if (mounted && generation == _generation) {
      setState(() {
        _candidates = candidates;
        _accepted.clear();
        _reviewVersion++;
        _message = candidates.isEmpty
            ? 'Aucun médicament reconnaissable dans le catalogue local. Vérifiez le texte ou saisissez le traitement manuellement dans le formulaire habituel.'
            : candidates.length >= 40
            ? '40 suggestions affichées au maximum : analysez une zone plus petite pour vérifier la suite.'
            : null;
      });
    }
  }

  Future<void> _extractCorrected() async {
    final generation = ++_generation;
    setState(() => _busy = true);
    try {
      await _extract(generation);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message = 'Texte trop long ou catalogue local indisponible. Réduisez le texte et réessayez.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (!_valid || _accepted.isEmpty) return;
    final drafts = _accepted.values.toList();
    setState(() => _importing = true);
    var imported = 0;
    try {
      for (final draft in drafts) {
        if (!mounted || !_valid) break;
        if (_saved.contains(draft.key)) continue;
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => MedicationFormScreen(
              repository: widget.repository,
              catalogRepository: _catalog,
              prescriptionDraft: draft,
              scanSessionValid: () =>
                  mounted && _valid && draft.sessionKey == _sessionKey,
            ),
          ),
        );
        if (saved == true) {
          _saved.add(draft.key);
          _accepted.remove(draft.key);
          imported++;
        } else {
          break;
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _message = imported > 0
              ? '$imported traitement(s) enregistré(s) après validation manuelle.'
              : _valid
              ? 'Aucun traitement ajouté sans votre validation finale.'
              : 'Import interrompu : session modifiée.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => MedicationScaffold(
    manageNotifications: false,
    backgroundColor: MedicationColors.canvas,
    appBar: AppBar(
      title: const Text(
        'Scanner une ordonnance',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: MedicationColors.ink,
        ),
      ),
      backgroundColor: Colors.white,
    ),
    body: ListView(
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
                Icons.document_scanner_outlined,
                size: 32,
                color: MedicationColors.teal,
              ),
              SizedBox(height: 12),
              Text(
                'Lire, vérifier, puis ajouter.',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: MedicationColors.ink,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Photo et texte temporaires, traités localement. L’OCR peut se tromper, surtout sur l’écriture manuscrite. Aucun traitement n’est ajouté automatiquement.',
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
        Text(
          _ocr.engine,
          style: const TextStyle(
            fontSize: 12,
            color: MedicationColors.teal,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Le scan reste temporaire et local. Après votre confirmation, le traitement est enregistré uniquement pour la session autorisée. Aucune identité patient n’est extraite.',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: MedicationColors.muted,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('scan-import-image'),
              onPressed: !_busy && !_importing ? () => _pick(false) : null,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                _cameraSupported
                    ? 'Importer depuis la galerie'
                    : 'Importer JPG / PNG',
              ),
            ),
            if (_cameraSupported)
              OutlinedButton.icon(
                key: const ValueKey('scan-camera'),
                onPressed: !_busy && !_importing ? () => _pick(true) : null,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Prendre une photo'),
              ),
          ],
        ),
        if (_cameraSupported)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Choisissez une photo JPG/PNG. Vérifiez l’aperçu avant de lancer l’analyse. '
              'Le recadrage est manuel, sans détection automatique des contours.',
              style: TextStyle(fontSize: 12, color: MedicationColors.muted),
            ),
          ),
        if (kIsWeb)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Chrome : import d’image et Tesseract local. ML Kit n’est pas disponible sur Web. La caméra native est réservée à Android/iOS.',
              style: TextStyle(fontSize: 12, color: MedicationColors.muted),
            ),
          ),
        if (_image != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(
              _preview!.bytes,
              key: const ValueKey('scan-image-preview'),
              height: 280,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: !_busy && !_importing
                    ? () => _transform(() => _images.rotate(_image!))
                    : null,
                icon: const Icon(Icons.rotate_right_rounded),
                label: const Text('Pivoter 90°'),
              ),
              TextButton.icon(
                onPressed: !_busy && !_importing ? _crop : null,
                icon: const Icon(Icons.crop_rounded),
                label: const Text('Recadrer'),
              ),
              TextButton(
                onPressed: !_busy && !_importing
                    ? () => _transform(() async => _original!)
                    : null,
                child: const Text('Image initiale'),
              ),
              TextButton(
                onPressed: !_busy && !_importing
                    ? () => _transform(() => _images.rotate(_image!, angle: -2))
                    : null,
                child: const Text('Redresser −2°'),
              ),
              TextButton(
                onPressed: !_busy && !_importing
                    ? () => _transform(() => _images.rotate(_image!, angle: 2))
                    : null,
                child: const Text('Redresser +2°'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PrescriptionImageMode>(
            key: ValueKey('scan-image-mode-${_imageMode.name}'),
            initialValue: _imageMode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Prétraitement local (aperçu réversible)',
            ),
            items: const [
              DropdownMenuItem(
                value: PrescriptionImageMode.original,
                child: Text('Original — conserver les traits'),
              ),
              DropdownMenuItem(
                value: PrescriptionImageMode.contrast,
                child: Text('Contraste et netteté douce'),
              ),
              DropdownMenuItem(
                value: PrescriptionImageMode.document,
                child: Text('Noir et blanc adaptatif'),
              ),
            ],
            onChanged: !_busy && !_importing
                ? (mode) {
                    if (mode != null) unawaited(_enhance(mode));
                  }
                : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'Comparez l’aperçu avec l’original. Un filtre peut effacer des traits fins ; il ne reconstitue pas une écriture illisible. Recadrez autour du texte en gardant une petite marge.',
            style: TextStyle(fontSize: 12, color: MedicationColors.muted),
          ),
          if (_image!.width < 600 || _image!.height < 600)
            const Text(
              'Petite image : une photo plus détaillée peut améliorer l’OCR.',
              style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('scan-analyze'),
            onPressed: !_busy && !_importing ? _analyze : null,
            icon: const Icon(Icons.manage_search_rounded),
            label: Text(
              _result == null ? 'Analyser localement' : 'Relancer l’analyse',
            ),
          ),
        ],
        if (_busy) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _progress,
            color: MedicationColors.teal,
          ),
          const SizedBox(height: 8),
          const Text(
            'Traitement local en cours… Le premier chargement du moteur peut prendre du temps.',
            style: TextStyle(fontSize: 12, color: MedicationColors.muted),
          ),
          TextButton(
            onPressed: () async {
              _generation++;
              await _ocr.cancel();
              if (mounted) {
                setState(() {
                  _busy = false;
                  _progress = null;
                  _message = 'Analyse annulée. Aucun traitement ajouté.';
                });
              }
            },
            child: const Text('Annuler l’analyse'),
          ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                key: const ValueKey('scan-message'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: MedicationColors.ink,
                ),
              ),
            ),
          ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          if ((_result!.confidence ?? 100) < 60)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Image peu fiable : reprenez une photo nette. Vérifiez chaque nom et chaque valeur sur l’ordonnance ; le score OCR ne valide aucune posologie.',
                style: TextStyle(color: Color(0xFFB45309), height: 1.5),
              ),
            ),
          MedicationBadge(
            label: _result!.confidence == null
                ? 'Texte OCR à vérifier'
                : 'Indice technique OCR : ${_result!.confidence!.toStringAsFixed(0)} / 100',
            color: const Color(0xFFB45309),
            icon: Icons.fact_check_outlined,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Cet indice n’est pas une probabilité de justesse médicale. Même un nom identique au catalogue et un indice élevé doivent être vérifiés.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: MedicationColors.muted,
              ),
            ),
          ),
          ExpansionTile(
            title: const Text('Texte brut extrait (non modifié)'),
            children: [
              SelectableText(
                _result!.text,
                key: const ValueKey('scan-raw-text'),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        MedicationSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vérifier ou corriger le texte',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: MedicationColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              if (_result == null)
                const Text(
                  'La saisie manuelle n’est pas une analyse OCR. Le texte original ne sera pas inventé.',
                  style: TextStyle(fontSize: 12, color: MedicationColors.muted),
                ),
              TextField(
                key: const ValueKey('scan-corrected-text'),
                onChanged: (_) => setState(() {
                  _accepted.clear();
                  _candidates = [];
                  _reviewVersion++;
                }),
                controller: _corrected,
                maxLines: 6,
                maxLength: 30000,
                enabled: !_busy && !_importing,
                decoration: const InputDecoration(
                  hintText: 'Corrigez ici uniquement ce que vous lisez sur l’ordonnance.',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: !_busy && !_importing ? _extractCorrected : null,
                child: const Text('Rechercher dans le catalogue local'),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey('scan-manual-medication'),
          onPressed: !_busy && !_importing && _candidates.length < 40
              ? _addManual
              : null,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Choisir un médicament manuellement'),
        ),
        if (_candidates.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Validation humaine obligatoire',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: MedicationColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les champs absents ou ambigus restent vides. Aucune heure n’est déduite d’une fréquence et aucune date n’est déduite de la date du scan.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: MedicationColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          for (final candidate in _candidates)
            if (!_saved.contains(candidate.key))
              PrescriptionReviewTile(
                key: ValueKey('$_reviewVersion-${candidate.key}'),
                candidate: candidate,
                sessionKey: _sessionKey,
                catalog: _catalog,
                enabled: !_busy && !_importing,
                onChanged: (draft) {
                  setState(() {
                    if (draft == null) {
                      _accepted.remove(candidate.key);
                    } else {
                      _accepted[candidate.key] = draft;
                    }
                  });
                },
              ),
          FilledButton.icon(
            key: const ValueKey('scan-open-forms'),
            onPressed: _valid && !_busy && !_importing && _accepted.isNotEmpty
                ? _import
                : null,
            icon: const Icon(Icons.playlist_add_check_rounded),
            label: Text(
              'Vérifier ${_accepted.length} médicament(s) dans le formulaire',
            ),
          ),
          if (!_valid)
            const Text(
              'Import bloqué : connectez-vous et vérifiez que votre session Médicaments est autorisée.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
        ],
        const SizedBox(height: 16),
        TextButton.icon(
          key: const ValueKey('scan-clear'),
          onPressed: !_importing ? _clear : null,
          icon: const Icon(Icons.clear_all_rounded),
          label: const Text('Effacer les données de scan de cette session'),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}

class _CropOverlay extends CustomPainter {
  _CropOverlay(this.horizontal, this.vertical);
  final RangeValues horizontal, vertical;
  @override
  void paint(Canvas canvas, Size size) {
    final rectangle = Rect.fromLTRB(
      horizontal.start / 100 * size.width,
      vertical.start / 100 * size.height,
      horizontal.end / 100 * size.width,
      vertical.end / 100 * size.height,
    );
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRect(rectangle)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: .45),
    );
    canvas.drawRect(
      rectangle,
      Paint()
        ..color = MedicationColors.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlay old) =>
      old.horizontal != horizontal || old.vertical != vertical;
}
