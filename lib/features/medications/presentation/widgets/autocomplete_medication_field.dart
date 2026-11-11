import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/medication_catalog_repository.dart';
import '../../domain/entities/medication_suggestion.dart';
import '../../domain/entities/medication_text_normalizer.dart';

class AutocompleteMedicationField extends StatefulWidget {
  const AutocompleteMedicationField({
    required this.controller,
    required this.onSuggestionSelected,
    this.onSuggestionCleared,
    this.onPresentationSelected,
    this.catalogRepository,
    this.validator,
    this.localOnly = false,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<MedicationSuggestion> onSuggestionSelected;
  final VoidCallback? onSuggestionCleared;
  final ValueChanged<String?>? onPresentationSelected;
  final MedicationCatalogRepository? catalogRepository;
  final FormFieldValidator<String>? validator;
  final bool localOnly;

  @override
  State<AutocompleteMedicationField> createState() =>
      _AutocompleteMedicationFieldState();
}

class _AutocompleteMedicationFieldState
    extends State<AutocompleteMedicationField> {
  static const _debounceDuration = Duration(milliseconds: 400);
  static const _maxVisibleSuggestions = 8;
  static const _nlmAttribution =
      'This product uses publicly available data from the U.S. National '
      'Library of Medicine (NLM), National Institutes of Health, Department '
      'of Health and Human Services; NLM is not responsible for the product '
      'and does not endorse or recommend this or any other product.';

  final _focusNode = FocusNode();
  Timer? _debounce;
  List<MedicationSuggestion> _suggestions = [];
  late final MedicationCatalogRepository _catalogRepository;
  DefaultMedicationCatalogRepository? _ownedCatalogRepository;
  MedicationSuggestion? _selectedSuggestion;
  int _requestId = 0;
  bool _isSearchingOnline = false;
  bool _hasSearchedLocally = false;
  bool _hasOnlineError = false;
  bool _hasLocalError = false;
  bool _showSuggestions = false;
  String? _selectedPresentation;

  @override
  void initState() {
    super.initState();
    final catalogRepository = widget.catalogRepository;
    if (catalogRepository == null) {
      final defaultRepository = DefaultMedicationCatalogRepository();
      _catalogRepository = defaultRepository;
      _ownedCatalogRepository = defaultRepository;
    } else {
      _catalogRepository = catalogRepository;
    }
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _requestId++;
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _ownedCatalogRepository?.close();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      setState(() => _showSuggestions = false);
    }
  }

  void _onTap() {
    if (_showSuggestions) return;
    setState(() => _showSuggestions = true);
    _loadLocalResults(widget.controller.text, ++_requestId);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final requestId = ++_requestId;
    if (_selectedSuggestion != null) {
      widget.onSuggestionCleared?.call();
    }
    setState(() {
      _showSuggestions = true;
      _selectedSuggestion = null;
      _selectedPresentation = null;
      _hasOnlineError = false;
      _hasLocalError = false;
      _isSearchingOnline = false;
      _hasSearchedLocally = false;
    });
    _loadLocalResults(value, requestId);
  }

  Future<void> _loadLocalResults(String query, int requestId) async {
    try {
      final localResults = await _catalogRepository.searchLocal(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = localResults;
        _hasSearchedLocally = true;
        _hasLocalError = false;
      });
      if (widget.localOnly || query.trim().length < 2) return;
      _debounce = Timer(_debounceDuration, () {
        _searchOnline(query, requestId);
      });
    } on Exception {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _hasSearchedLocally = true;
        _hasLocalError = true;
      });
      if (!widget.localOnly && query.trim().length >= 2) {
        _debounce = Timer(_debounceDuration, () {
          _searchOnline(query, requestId);
        });
      }
    }
  }

  Future<void> _searchOnline(String query, int requestId) async {
    if (widget.localOnly) return;
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _isSearchingOnline = true;
      _hasOnlineError = false;
    });
    try {
      final onlineResults = await _catalogRepository.searchOnline(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = _mergeSuggestions(_suggestions, onlineResults);
        _isSearchingOnline = false;
      });
    } on Exception {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isSearchingOnline = false;
        _hasOnlineError = true;
      });
    }
  }

  List<MedicationSuggestion> _mergeSuggestions(
    List<MedicationSuggestion> local,
    List<MedicationSuggestion> online,
  ) {
    final merged = [...local];
    final keys = local.map(_suggestionKey).toSet();
    for (final suggestion in online) {
      if (merged.length == _maxVisibleSuggestions) break;
      if (keys.add(_suggestionKey(suggestion))) merged.add(suggestion);
    }
    return merged;
  }

  String _suggestionKey(MedicationSuggestion suggestion) {
    return [
      suggestion.name,
      suggestion.activeIngredient ?? '',
      ...suggestion.presentations,
    ].map(normalizeMedicationText).join('|');
  }

  void _selectSuggestion(MedicationSuggestion suggestion) {
    _debounce?.cancel();
    _requestId++;
    widget.controller.text = suggestion.name;
    setState(() {
      _showSuggestions = false;
      _selectedSuggestion = suggestion;
      _selectedPresentation = null;
      _isSearchingOnline = false;
    });
    _focusNode.unfocus();
    widget.onSuggestionSelected(suggestion);
  }

  void _selectManualEntry() {
    _debounce?.cancel();
    _requestId++;
    widget.onSuggestionCleared?.call();
    setState(() {
      _showSuggestions = false;
      _selectedSuggestion = null;
      _isSearchingOnline = false;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          onTap: _onTap,
          onChanged: _onQueryChanged,
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: 'Nom du médicament',
            hintText: 'Ex : Doliprane',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF0D9488)),
            suffixIcon: _isSearchingOnline
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF0D9488), width: 2),
            ),
          ),
        ),
        if (_showSuggestions) ...[
          const SizedBox(height: 8),
          TextFieldTapRegion(child: _suggestionList()),
          if (_isSearchingOnline) ...[
            const SizedBox(height: 6),
            const LinearProgressIndicator(
              color: Color(0xFF0D9488),
              backgroundColor: Color(0xFFE2E8F0),
            ),
          ],
          if (_hasLocalError) ...[
            const SizedBox(height: 6),
            _statusMessage(
              'Le catalogue local est indisponible. Vous pouvez saisir le nom manuellement.',
              Icons.error_outline,
            ),
          ],
          if (_hasOnlineError) ...[
            const SizedBox(height: 6),
            _statusMessage(
              'Résultats hors ligne affichés. La recherche en ligne est indisponible.',
              Icons.wifi_off_outlined,
            ),
          ],
        ] else if (_selectedSuggestion case final suggestion?) ...[
          const SizedBox(height: 8),
          _selectedDetails(suggestion),
        ],
      ],
    );
  }

  Widget _suggestionList() {
    final hasNoResults = _hasSearchedLocally && _suggestions.isEmpty;
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Text(
                'Médicaments courants et suggestions',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasNoResults)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  'Aucun résultat. Vous pouvez saisir le nom manuellement.',
                  style: TextStyle(color: Color(0xFF475569)),
                ),
              ),
            for (final suggestion in _suggestions) _suggestionTile(suggestion),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.edit_outlined,
                color: Color(0xFF0D9488),
              ),
              title: const Text('Saisir manuellement'),
              onTap: _selectManualEntry,
            ),
            TextButton.icon(
              onPressed: _showSourceDisclosure,
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('Sources et informations sur le catalogue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionTile(MedicationSuggestion suggestion) {
    return InkWell(
      onTap: () => _selectSuggestion(suggestion),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.medication_outlined, color: Color(0xFF0D9488)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (suggestion.activeIngredient case final ingredient?)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Substance active : $ingredient',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  if (suggestion.presentations.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Présentations commerciales : '
                        '${suggestion.presentations.join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.north_west, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _selectedDetails(MedicationSuggestion suggestion) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (suggestion.activeIngredient case final ingredient?)
            Text(
              'Substance active vérifiée : $ingredient',
              style: const TextStyle(color: Color(0xFF475569)),
            ),
          if (suggestion.presentations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Présentations commerciales (informatif) : '
                '${suggestion.presentations.join(', ')}',
                style: const TextStyle(color: Color(0xFF475569)),
              ),
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Présentation commerciale (facultative)',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPresentation,
                  isExpanded: true,
                  hint: const Text('Choisir une présentation'),
                  items: suggestion.presentations
                      .map(
                        (presentation) => DropdownMenuItem(
                          value: presentation,
                          child: Text(
                            presentation,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (presentation) {
                    setState(() => _selectedPresentation = presentation);
                    widget.onPresentationSelected?.call(presentation);
                  },
                ),
              ),
            ),
          ],
          if (_selectedPresentation case final presentation?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Présentation choisie : $presentation',
                style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            'La posologie et le calendrier du traitement restent à saisir.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statusMessage(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSourceDisclosure() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sources du catalogue'),
        content: const SingleChildScrollView(
          child: Text(
            'Le catalogue local a été vérifié le 29/10/2026 à partir de la '
            'Base de Données Publique des Médicaments (BDPM), publiée par le '
            'Ministère français de la Santé : '
            'https://base-donnees-publique.medicaments.gouv.fr/telechargement. '
            'Les données BDPM sont publiées sous Licence Ouverte 2.0 '
            '(Etalab, fr-lo). Les présentations listées sont des informations '
            'de référence, pas une posologie personnelle.\n\n'
            'Panadol est une marque issue de RxNorm (NLM), sans affirmation '
            'de disponibilité régionale. Amoxil est un nom fourni dans la '
            'demande; sa substance active et ses présentations ne sont pas '
            'renseignées faute de source vérifiée. La liste DPM Tunisie a été '
            'étudiée mais ses conditions de réutilisation n’étant pas '
            'explicitement indiquées, ses données ne sont pas intégrées.\n\n'
            '$_nlmAttribution',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
