import 'package:flutter/foundation.dart';

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

enum BiologicalSex {
  male('Homme'),
  female('Femme'),
  other('Autre');

  const BiologicalSex(this.label);
  final String label;
}

enum SmokingStatus {
  never('Non-fumeur'),
  former('Ancien fumeur'),
  occasional('Occasionnel'),
  regular('Régulier');

  const SmokingStatus(this.label);
  final String label;
}

enum AlcoholConsumption {
  none('Jamais'),
  occasional('Occasionnelle'),
  moderate('Modérée'),
  frequent('Fréquente');

  const AlcoholConsumption(this.label);
  final String label;
}

enum PhysicalActivity {
  sedentary('Sédentaire'),
  light('Légère'),
  moderate('Modérée'),
  intense('Intense');

  const PhysicalActivity(this.label);
  final String label;
}

enum BmiCategory {
  underweight('Insuffisance pondérale'),
  normal('Poids normal'),
  overweight('Surpoids'),
  obese('Obésité');

  const BmiCategory(this.label);
  final String label;

  static BmiCategory fromBmi(double bmi) {
    if (bmi < 18.5) return BmiCategory.underweight;
    if (bmi < 25) return BmiCategory.normal;
    if (bmi < 30) return BmiCategory.overweight;
    return BmiCategory.obese;
  }
}

/// Élément pris en compte dans le calcul de complétion du profil.
@immutable
class CompletionItem {
  const CompletionItem(this.label, this.isDone);
  final String label;
  final bool isDone;
}

/// Profil utilisateur (Gestion 1). Les maladies, allergies et antécédents
/// ne font volontairement PAS partie de ce modèle : ils sont en lecture seule
/// (voir `medical_history.dart`).
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    this.fullName = '',
    this.email = '',
    this.dateOfBirth,
    this.sex,
    this.bloodGroup,
    this.rhesus,
    this.heightCm,
    this.weightKg,
    this.smoking,
    this.alcohol,
    this.activity,
  });

  final String id;
  final String fullName;
  final String email;
  final DateTime? dateOfBirth;
  final BiologicalSex? sex;
  final String? bloodGroup; // A, B, AB, O
  final String? rhesus; // +, -
  final double? heightCm;
  final double? weightKg;
  final SmokingStatus? smoking;
  final AlcoholConsumption? alcohol;
  final PhysicalActivity? activity;

  // ---------------------------------------------------------------------------
  // Valeurs calculées
  // ---------------------------------------------------------------------------
  String? get bloodType =>
      (bloodGroup == null || rhesus == null) ? null : '$bloodGroup$rhesus';

  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) years--;
    return years < 0 ? null : years;
  }

  /// IMC = poids (kg) / taille (m)². `null` si données manquantes ou invalides.
  double? get bmi {
    final h = heightCm;
    final w = weightKg;
    if (h == null || w == null || h <= 0 || w <= 0) return null;
    final m = h / 100;
    return w / (m * m);
  }

  BmiCategory? get bmiCategory => bmi == null ? null : BmiCategory.fromBmi(bmi!);

  List<CompletionItem> get completionItems => [
        CompletionItem('Nom complet', fullName.trim().isNotEmpty),
        CompletionItem('Date de naissance', dateOfBirth != null),
        CompletionItem('Sexe biologique', sex != null),
        CompletionItem('Groupe sanguin', bloodType != null),
        CompletionItem('Taille', heightCm != null),
        CompletionItem('Poids', weightKg != null),
        CompletionItem('Statut tabagique', smoking != null),
        CompletionItem('Consommation d\'alcool', alcohol != null),
        CompletionItem('Activité physique', activity != null),
      ];

  /// Pourcentage de complétion dans [0, 1].
  double get completion {
    final items = completionItems;
    return items.where((i) => i.isDone).length / items.length;
  }

  UserProfile copyWith({
    String? fullName,
    String? email,
    DateTime? dateOfBirth,
    BiologicalSex? sex,
    String? bloodGroup,
    String? rhesus,
    double? heightCm,
    double? weightKg,
    SmokingStatus? smoking,
    AlcoholConsumption? alcohol,
    PhysicalActivity? activity,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      sex: sex ?? this.sex,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      rhesus: rhesus ?? this.rhesus,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      smoking: smoking ?? this.smoking,
      alcohol: alcohol ?? this.alcohol,
      activity: activity ?? this.activity,
    );
  }

  // ---------------------------------------------------------------------------
  // Sérialisation Supabase (table `profiles`)
  // ---------------------------------------------------------------------------
  factory UserProfile.fromMap(Map<String, dynamic> map, {String email = ''}) {
    return UserProfile(
      id: map['id'] as String,
      email: email,
      fullName: (map['full_name'] as String?) ?? '',
      dateOfBirth: map['date_of_birth'] == null ? null : DateTime.tryParse(map['date_of_birth'] as String),
      sex: _enumByName(BiologicalSex.values, map['biological_sex']),
      bloodGroup: map['blood_group'] as String?,
      rhesus: map['rhesus'] as String?,
      heightCm: (map['height_cm'] as num?)?.toDouble(),
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      smoking: _enumByName(SmokingStatus.values, map['smoking_status']),
      alcohol: _enumByName(AlcoholConsumption.values, map['alcohol_consumption']),
      activity: _enumByName(PhysicalActivity.values, map['physical_activity']),
    );
  }

  Map<String, dynamic> toMap() {
    final dob = dateOfBirth;
    return {
      'id': id,
      'full_name': fullName.trim(),
      'date_of_birth': dob == null
          ? null
          : '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}',
      'biological_sex': sex?.name,
      'blood_group': bloodGroup,
      'rhesus': rhesus,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'smoking_status': smoking?.name,
      'alcohol_consumption': alcohol?.name,
      'physical_activity': activity?.name,
    };
  }
}
