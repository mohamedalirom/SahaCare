import 'package:flutter/foundation.dart';

/// Spécialité médicale recommandée par l'orientation
@immutable
class RecommendedSpecialty {
  final String name;
  final String reason;
  final String confidence; // 'high' | 'medium' | 'low'

  const RecommendedSpecialty({
    required this.name,
    required this.reason,
    required this.confidence,
  });

  factory RecommendedSpecialty.fromJson(Map<String, dynamic> json) {
    return RecommendedSpecialty(
      name: json['name'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      confidence: (json['confidence'] as String? ?? 'medium').toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'reason': reason,
        'confidence': confidence,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendedSpecialty &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          reason == other.reason &&
          confidence == other.confidence;

  @override
  int get hashCode => Object.hash(name, reason, confidence);
}

/// Résultat complet de l'analyse d'orientation
@immutable
class OrientationResult {
  final List<RecommendedSpecialty> recommendedSpecialties;
  final String urgency; // 'routine' | 'soon' | 'emergency'
  final bool needsMoreInfo;
  final String? clarificationQuestion;
  final String advice;
  final bool isDegradedMode;

  const OrientationResult({
    required this.recommendedSpecialties,
    required this.urgency,
    required this.needsMoreInfo,
    this.clarificationQuestion,
    required this.advice,
    this.isDegradedMode = false,
  });

  factory OrientationResult.fromJson(Map<String, dynamic> json, {bool isDegradedMode = false}) {
    final rawSpecs = json['recommended_specialties'] as List<dynamic>? ?? [];
    final specs = rawSpecs
        .whereType<Map<String, dynamic>>()
        .map((e) => RecommendedSpecialty.fromJson(e))
        .where((s) => s.name.trim().isNotEmpty)
        .toList();

    return OrientationResult(
      recommendedSpecialties: specs,
      urgency: (json['urgency'] as String? ?? 'routine').toLowerCase(),
      needsMoreInfo: json['needs_more_info'] as bool? ?? false,
      clarificationQuestion: json['clarification_question'] as String?,
      advice: json['advice'] as String? ?? '',
      isDegradedMode: isDegradedMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'recommended_specialties':
            recommendedSpecialties.map((s) => s.toJson()).toList(),
        'urgency': urgency,
        'needs_more_info': needsMoreInfo,
        if (clarificationQuestion != null)
          'clarification_question': clarificationQuestion,
        'advice': advice,
        'is_degraded_mode': isDegradedMode,
      };

  OrientationResult copyWith({
    List<RecommendedSpecialty>? recommendedSpecialties,
    String? urgency,
    bool? needsMoreInfo,
    String? clarificationQuestion,
    String? advice,
    bool? isDegradedMode,
  }) {
    return OrientationResult(
      recommendedSpecialties:
          recommendedSpecialties ?? this.recommendedSpecialties,
      urgency: urgency ?? this.urgency,
      needsMoreInfo: needsMoreInfo ?? this.needsMoreInfo,
      clarificationQuestion:
          clarificationQuestion ?? this.clarificationQuestion,
      advice: advice ?? this.advice,
      isDegradedMode: isDegradedMode ?? this.isDegradedMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrientationResult &&
          runtimeType == other.runtimeType &&
          listEquals(recommendedSpecialties, other.recommendedSpecialties) &&
          urgency == other.urgency &&
          needsMoreInfo == other.needsMoreInfo &&
          clarificationQuestion == other.clarificationQuestion &&
          advice == other.advice &&
          isDegradedMode == other.isDegradedMode;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(recommendedSpecialties),
        urgency,
        needsMoreInfo,
        clarificationQuestion,
        advice,
        isDegradedMode,
      );
}
