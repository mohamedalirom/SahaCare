import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Entrée d'historique de consultation d'orientation
@immutable
class OrientationHistoryEntry {
  final String id;
  final String date;
  final String text;
  final List<String> suggestedSpecialties;
  final String urgency;
  final String advice;

  const OrientationHistoryEntry({
    required this.id,
    required this.date,
    required this.text,
    required this.suggestedSpecialties,
    required this.urgency,
    required this.advice,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'text': text,
        'suggested_specialties': jsonEncode(suggestedSpecialties),
        'urgency': urgency,
        'advice': advice,
      };

  factory OrientationHistoryEntry.fromMap(Map<String, dynamic> map) {
    List<String> specs = [];
    final raw = map['suggested_specialties'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          specs = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return OrientationHistoryEntry(
      id: map['id'] as String? ?? '',
      date: map['date'] as String? ?? '',
      text: map['text'] as String? ?? '',
      suggestedSpecialties: specs,
      urgency: map['urgency'] as String? ?? 'routine',
      advice: map['advice'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrientationHistoryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          text == other.text &&
          listEquals(suggestedSpecialties, other.suggestedSpecialties) &&
          urgency == other.urgency &&
          advice == other.advice;

  @override
  int get hashCode => Object.hash(
        id,
        date,
        text,
        Object.hashAll(suggestedSpecialties),
        urgency,
        advice,
      );
}
