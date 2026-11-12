import 'package:flutter/foundation.dart';

/// Modèles du dossier médical (maladies, allergies, antécédents).
///
/// Les mutations passent par `MedicalRepository` (SQLite + outbox).

bool _asBool(Object? v) => v == true || v == 1 || v == '1' || v == 'true';

String? _dateOnly(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

@immutable
class Disease {
  const Disease({required this.id, required this.name, this.diagnosedAt, this.isChronic = false});

  final String id;
  final String name;
  final DateTime? diagnosedAt;
  final bool isChronic;

  factory Disease.fromMap(Map<String, dynamic> map) => Disease(
        id: '${map['id']}',
        name: (map['name'] as String?) ?? '',
        diagnosedAt: map['diagnosed_at'] == null ? null : DateTime.tryParse('${map['diagnosed_at']}'),
        isChronic: _asBool(map['is_chronic']),
      );

  /// Colonnes locales (hors `profile_id` / `updated_at`, ajoutés par le dépôt).
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'diagnosed_at': _dateOnly(diagnosedAt),
        'is_chronic': isChronic ? 1 : 0,
      };

  Disease copyWith({String? name, DateTime? diagnosedAt, bool? isChronic}) => Disease(
        id: id,
        name: name ?? this.name,
        diagnosedAt: diagnosedAt ?? this.diagnosedAt,
        isChronic: isChronic ?? this.isChronic,
      );

  @override
  bool operator ==(Object other) =>
      other is Disease &&
      other.id == id &&
      other.name == name &&
      other.diagnosedAt == diagnosedAt &&
      other.isChronic == isChronic;

  @override
  int get hashCode => Object.hash(id, name, diagnosedAt, isChronic);
}

enum AllergySeverity {
  mild('Légère'),
  moderate('Modérée'),
  severe('Sévère');

  const AllergySeverity(this.label);
  final String label;

  static AllergySeverity fromName(Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return AllergySeverity.mild;
  }
}

enum AllergyKind {
  medication('Médicament'),
  food('Alimentaire'),
  other('Autre');

  const AllergyKind(this.label);
  final String label;

  static AllergyKind fromName(Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return AllergyKind.other;
  }
}

@immutable
class Allergy {
  const Allergy({
    required this.id,
    required this.name,
    this.severity = AllergySeverity.mild,
    this.kind = AllergyKind.other,
  });

  final String id;
  final String name;
  final AllergySeverity severity;
  final AllergyKind kind;

  factory Allergy.fromMap(Map<String, dynamic> map) => Allergy(
        id: '${map['id']}',
        name: (map['name'] as String?) ?? '',
        severity: AllergySeverity.fromName(map['severity']),
        kind: AllergyKind.fromName(map['kind']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'severity': severity.name,
        'kind': kind.name,
      };

  Allergy copyWith({String? name, AllergySeverity? severity, AllergyKind? kind}) => Allergy(
        id: id,
        name: name ?? this.name,
        severity: severity ?? this.severity,
        kind: kind ?? this.kind,
      );

  @override
  bool operator ==(Object other) =>
      other is Allergy && other.id == id && other.name == name && other.severity == severity && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, name, severity, kind);
}

@immutable
class MedicalHistoryEntry {
  const MedicalHistoryEntry({required this.id, required this.title, this.description = '', this.date});

  final String id;
  final String title;
  final String description;
  final DateTime? date;

  factory MedicalHistoryEntry.fromMap(Map<String, dynamic> map) => MedicalHistoryEntry(
        id: '${map['id']}',
        title: (map['title'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        date: map['event_date'] == null ? null : DateTime.tryParse('${map['event_date']}'),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'event_date': _dateOnly(date),
      };

  MedicalHistoryEntry copyWith({String? title, String? description, DateTime? date}) => MedicalHistoryEntry(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        date: date ?? this.date,
      );

  @override
  bool operator ==(Object other) =>
      other is MedicalHistoryEntry &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.date == date;

  @override
  int get hashCode => Object.hash(id, title, description, date);
}

@immutable
class MedicalHistory {
  const MedicalHistory({
    this.diseases = const [],
    this.allergies = const [],
    this.history = const [],
  });

  final List<Disease> diseases;
  final List<Allergy> allergies;
  final List<MedicalHistoryEntry> history;
}
