import 'dart:typed_data';

import 'medication_suggestion.dart';

enum PrescriptionMatchLevel { exact, ingredient, close, tentative }

class PrescriptionCatalogMatch {
  const PrescriptionCatalogMatch(this.medication, this.level);
  final MedicationSuggestion medication;
  final PrescriptionMatchLevel level;
  String get explanation => switch (level) {
    PrescriptionMatchLevel.exact => 'Nom identique dans le texte — à vérifier',
    PrescriptionMatchLevel.ingredient =>
      'Substance ou alias écrit — marque à choisir',
    PrescriptionMatchLevel.close => 'Nom proche — correspondance incertaine',
    PrescriptionMatchLevel.tentative =>
      'Ressemblance limitée — forte incertitude',
  };
}

class PrescriptionImage {
  const PrescriptionImage({
    required this.bytes,
    required this.width,
    required this.height,
  });
  final Uint8List bytes;
  final int width;
  final int height;
}

class PrescriptionOcrResult {
  const PrescriptionOcrResult({
    required this.text,
    required this.engine,
    this.confidence,
  });
  final String text;
  final String engine;
  final double? confidence;
}

class PrescriptionCandidate {
  const PrescriptionCandidate({
    required this.key,
    required this.line,
    required this.sourceText,
    required this.matches,
    required this.exactName,
    this.strength,
    this.frequency,
    this.durationDays,
    this.times = const [],
    this.daily = false,
    this.startDate,
    this.endDate,
    this.repeated = false,
    this.lineAmbiguous = false,
    this.evidence = const [],
    this.lowQuality = false,
  });
  final String key;
  final int line;
  final String sourceText;
  final List<MedicationSuggestion> matches;
  final bool exactName;
  final String? strength;
  final String? frequency;
  final int? durationDays;
  final List<String> times;
  final bool daily;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool repeated;
  final bool lineAmbiguous;
  final List<PrescriptionCatalogMatch> evidence;
  final bool lowQuality;
  bool get uncertain =>
      lowQuality || lineAmbiguous || !exactName || matches.length != 1;
}

/// In-memory only. No JSON serialization, patient identity, reminder or stock fields.
class PrescriptionDraft {
  const PrescriptionDraft({
    required this.key,
    required this.sessionKey,
    required this.name,
    this.activeIngredient,
    this.presentation,
    this.dosage = '',
    this.times = const [],
    this.durationDays,
    this.weekdaysMask = 0,
    this.startDate,
    this.endDate,
  });
  final String key;
  final String sessionKey;
  final String name;
  final String? activeIngredient;
  final String? presentation;
  final String dosage;
  final List<String> times;
  final int? durationDays;
  final int weekdaysMask;
  final DateTime? startDate;
  final DateTime? endDate;
}
