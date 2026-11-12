class MedicationSuggestion {
  const MedicationSuggestion({
    required this.name,
    this.activeIngredient,
    this.searchTerms = const [],
    this.presentations = const [],
    this.rxCui,
    this.source,
  });

  final String name;
  final String? activeIngredient;
  final List<String> searchTerms;
  final List<String> presentations;
  final String? rxCui;
  final String? source;
}
