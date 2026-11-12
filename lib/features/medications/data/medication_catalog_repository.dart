import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/entities/medication_suggestion.dart';
import '../domain/entities/medication_text_normalizer.dart';
import 'services/medication_search_service.dart';

abstract interface class MedicationCatalogRepository {
  Future<List<MedicationSuggestion>> searchLocal(String query);

  Future<List<MedicationSuggestion>> searchOnline(String query);
}

class DefaultMedicationCatalogRepository
    implements MedicationCatalogRepository {
  DefaultMedicationCatalogRepository({
    AssetBundle? assetBundle,
    MedicationSearchService? searchService,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _searchService = searchService ?? MedicationSearchService(),
       _ownsSearchService = searchService == null;

  static const _catalogPath = 'assets/data/medication_catalog.json';

  final AssetBundle _assetBundle;
  final MedicationSearchService _searchService;
  final bool _ownsSearchService;
  Future<List<MedicationSuggestion>>? _catalog;

  void close() {
    if (_ownsSearchService) _searchService.close();
  }

  @override
  Future<List<MedicationSuggestion>> searchLocal(String query) async {
    final catalog = await (_catalog ??= _loadCatalog());
    final normalizedQuery = normalizeMedicationText(query);
    if (normalizedQuery.isEmpty) return catalog;
    return catalog
        .where(
          (suggestion) =>
              [
                suggestion.name,
                suggestion.activeIngredient ?? '',
                ...suggestion.searchTerms,
                ...suggestion.presentations,
              ].any(
                (value) =>
                    normalizeMedicationText(value).contains(normalizedQuery),
              ),
        )
        .toList();
  }

  @override
  Future<List<MedicationSuggestion>> searchOnline(String query) {
    return _searchService.search(query);
  }

  Future<List<MedicationSuggestion>> _loadCatalog() async {
    final decoded = jsonDecode(await _assetBundle.loadString(_catalogPath));
    if (decoded is! Map<String, dynamic> || decoded['medications'] is! List) {
      throw const FormatException('Le catalogue local est invalide.');
    }
    return (decoded['medications'] as List)
        .whereType<Map<String, dynamic>>()
        .map(
          (record) => MedicationSuggestion(
            name: record['name'] as String,
            activeIngredient: record['activeIngredient'] as String?,
            searchTerms:
                (record['searchTerms'] as List?)
                    ?.whereType<String>()
                    .toList() ??
                const [],
            presentations:
                (record['presentations'] as List?)
                    ?.whereType<String>()
                    .toList() ??
                const [],
            source: record['source'] as String?,
          ),
        )
        .toList();
  }
}
