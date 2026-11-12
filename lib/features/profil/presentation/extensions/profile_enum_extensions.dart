import '../../domain/entities/medical_history.dart';
import '../../domain/entities/user_profile.dart';
import '../../../../i18n/strings.g.dart';

extension BiologicalSexL10n on BiologicalSex {
  String get localized => switch (this) {
        BiologicalSex.male => t.biologicalSexOptions.male,
        BiologicalSex.female => t.biologicalSexOptions.female,
        BiologicalSex.other => t.biologicalSexOptions.other,
      };
}

extension SmokingStatusL10n on SmokingStatus {
  String get localized => switch (this) {
        SmokingStatus.never => t.smokingStatus.never,
        SmokingStatus.former => t.smokingStatus.former,
        SmokingStatus.occasional => t.smokingStatus.occasional,
        SmokingStatus.regular => t.smokingStatus.regular,
      };
}

extension AlcoholConsumptionL10n on AlcoholConsumption {
  String get localized => switch (this) {
        AlcoholConsumption.none => t.alcoholConsumption.none,
        AlcoholConsumption.occasional => t.alcoholConsumption.occasional,
        AlcoholConsumption.moderate => t.alcoholConsumption.moderate,
        AlcoholConsumption.frequent => t.alcoholConsumption.frequent,
      };
}

extension PhysicalActivityL10n on PhysicalActivity {
  String get localized => switch (this) {
        PhysicalActivity.sedentary => t.physicalActivityOptions.sedentary,
        PhysicalActivity.light => t.physicalActivityOptions.light,
        PhysicalActivity.moderate => t.physicalActivityOptions.moderate,
        PhysicalActivity.intense => t.physicalActivityOptions.intense,
      };
}

extension RhesusFormat on String {
  String get localizedRhesus =>
      this == '+' ? t.rhesusOptions.positive : t.rhesusOptions.negative;
}

extension AllergySeverityL10n on AllergySeverity {
  String get localized => switch (this) {
        AllergySeverity.mild => t.allergySeverityOptions.mild,
        AllergySeverity.moderate => t.allergySeverityOptions.moderate,
        AllergySeverity.severe => t.allergySeverityOptions.severe,
      };
}

extension AllergyKindL10n on AllergyKind {
  String get localized => switch (this) {
        AllergyKind.medication => t.allergyKindOptions.medication,
        AllergyKind.food => t.allergyKindOptions.food,
        AllergyKind.other => t.allergyKindOptions.other,
      };
}

