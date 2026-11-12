import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/medication_suggestion.dart';
import '../../domain/entities/medication_text_normalizer.dart';

class MedicationSearchService {
  MedicationSearchService({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _baseUri = baseUri ?? Uri.https('rxnav.nlm.nih.gov', '/REST');

  static const _maxCandidates = 10;
  static const _maxExpandedCandidates = 3;
  static const _cacheDuration = Duration(hours: 12);

  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUri;
  final _cache = <String, _CachedSearch>{};

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<List<MedicationSuggestion>> search(String query) async {
    final term = query.trim();
    if (term.length < 2) return [];
    final cacheKey = normalizeMedicationText(term);
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.savedAt) < _cacheDuration) {
      return cached.results;
    }

    final response = await _getJson('approximateTerm.json', {
      'term': term,
      'maxEntries': '$_maxCandidates',
      'option': '1',
    });
    final approximateGroup = _asMap(response['approximateGroup']);
    final candidates = _asMaps(approximateGroup?['candidate']);
    final uniqueCandidates = <String, Map<String, dynamic>>{};
    for (final candidate in candidates) {
      final rxCui = _asString(candidate['rxcui']);
      if (rxCui == null) continue;
      uniqueCandidates.putIfAbsent(rxCui, () => candidate);
    }

    final expanded = await Future.wait(
      uniqueCandidates.values
          .take(_maxExpandedCandidates)
          .map(_expandCandidate),
    );
    final suggestions = <MedicationSuggestion>[];
    final seen = <String>{};
    for (final group in expanded) {
      for (final suggestion in group) {
        final key = [
          suggestion.name,
          suggestion.activeIngredient ?? '',
          ...suggestion.presentations,
        ].map(normalizeMedicationText).join('|');
        if (seen.add(key)) suggestions.add(suggestion);
        if (suggestions.length == _maxCandidates) return suggestions;
      }
    }
    _cache[cacheKey] = _CachedSearch(DateTime.now(), suggestions);
    return suggestions;
  }

  Future<List<MedicationSuggestion>> _expandCandidate(
    Map<String, dynamic> candidate,
  ) async {
    final rxCui = _asString(candidate['rxcui'])!;
    final propertiesResponse = await _getJson('rxcui/$rxCui/properties.json');
    final properties = _asMap(propertiesResponse['properties']);
    final canonicalName =
        _asString(properties?['name']) ?? _asString(candidate['name']);
    if (canonicalName == null) return [];
    final termType = _asString(properties?['tty']);
    if (termType == 'IN' || termType == 'PIN' || termType == 'BN') {
      final ingredients = termType == 'BN'
          ? await _relatedIngredientNamesFor(rxCui)
          : [canonicalName];
      final drugResponse = await _getJson('drugs.json', {
        'name': canonicalName,
      });
      final products = _productSuggestions(
        drugResponse,
        activeIngredient: ingredients.join(' / '),
      );
      return products.isEmpty
          ? [
              MedicationSuggestion(
                name: canonicalName,
                activeIngredient: ingredients.join(' / '),
                rxCui: rxCui,
                source: _asString(candidate['source']),
              ),
            ]
          : products;
    }

    if (termType == 'SCD' || termType == 'SBD') {
      final ingredients = await _relatedIngredientNamesFor(rxCui);
      return [
        MedicationSuggestion(
          name: canonicalName,
          activeIngredient: ingredients.isEmpty
              ? null
              : ingredients.join(' / '),
          presentations: _commercialPresentation(canonicalName),
          rxCui: rxCui,
          source: _asString(candidate['source']),
        ),
      ];
    }

    return [
      MedicationSuggestion(
        name: canonicalName,
        rxCui: rxCui,
        source: _asString(candidate['source']),
      ),
    ];
  }

  List<MedicationSuggestion> _productSuggestions(
    Map<String, dynamic> response, {
    required String activeIngredient,
  }) {
    final drugGroup = _asMap(response['drugGroup']);
    final grouped = <String, MedicationSuggestion>{};
    for (final conceptGroup in _asMaps(drugGroup?['conceptGroup'])) {
      final termType = _asString(conceptGroup['tty']);
      if (termType != 'SCD' && termType != 'SBD') continue;
      for (final product in _asMaps(conceptGroup['conceptProperties'])) {
        if (_asString(product['suppress']) == 'Y') continue;
        final name = _asString(product['name']);
        final rxCui = _asString(product['rxcui']);
        if (name == null || rxCui == null) continue;
        final brandMatch = RegExp(r'\[([^\]]+)\]\s*$').firstMatch(name);
        final displayName = brandMatch?.group(1) ?? activeIngredient;
        final presentation = _commercialPresentation(name);
        final key =
            '${normalizeMedicationText(displayName)}|'
            '${normalizeMedicationText(activeIngredient)}';
        final previous = grouped[key];
        grouped[key] = MedicationSuggestion(
          name: displayName,
          activeIngredient: activeIngredient,
          presentations: {
            ...?previous?.presentations,
            ...presentation,
          }.toList(),
          rxCui: rxCui,
          source: 'RXNORM',
        );
        if (grouped.length == _maxCandidates) break;
      }
      if (grouped.length == _maxCandidates) break;
    }
    return grouped.values.toList();
  }

  Future<List<String>> _relatedIngredientNamesFor(String rxCui) async {
    final response = await _getJson('rxcui/$rxCui/related.json', {'tty': 'IN'});
    return _relatedIngredientNames(response);
  }

  List<String> _relatedIngredientNames(Map<String, dynamic> response) {
    final relatedGroup = _asMap(response['relatedGroup']);
    final names = <String>{};
    for (final group in _asMaps(relatedGroup?['conceptGroup'])) {
      if (_asString(group['tty']) != 'IN') continue;
      for (final ingredient in _asMaps(group['conceptProperties'])) {
        final name = _asString(ingredient['name']);
        if (name != null) names.add(name);
      }
    }
    return names.toList();
  }

  Future<Map<String, dynamic>> _getJson(
    String endpoint, [
    Map<String, String> queryParameters = const {},
  ]) async {
    final uri = _baseUri.replace(
      path: '${_baseUri.path}/$endpoint',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw MedicationSearchException(
        'RxNorm returned HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    final result = _asMap(decoded);
    if (result == null) {
      throw const FormatException('RxNorm returned an invalid JSON object.');
    }
    return result;
  }

  List<String> _commercialPresentation(String name) {
    final strengths = RegExp(
      r'\b\d+(?:\.\d+)?\s*(?:MCG/ML|MG/ML|G/ML|MG|MCG|G|MEQ|%)'
      r'(?:\s*/\s*\d+(?:\.\d+)?\s*(?:MG|MCG|G|ML))?',
      caseSensitive: false,
    ).allMatches(name).toList();
    if (strengths.isEmpty) return [];
    final strength = strengths
        .map((match) => match.group(0)!.trim())
        .join(' / ');
    final lastStrength = strengths.last;
    final form = name
        .substring(lastStrength.end)
        .replaceFirst(RegExp(r'\s*\[[^\]]+\]\s*$'), '')
        .trim();
    return [form.isEmpty ? strength : '$strength • $form'];
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  static List<Map<String, dynamic>> _asMaps(dynamic value) {
    if (value is Map<String, dynamic>) return [value];
    if (value is! List) return [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  static String? _asString(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }
}

class _CachedSearch {
  const _CachedSearch(this.savedAt, this.results);

  final DateTime savedAt;
  final List<MedicationSuggestion> results;
}

class MedicationSearchException implements Exception {
  const MedicationSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}
