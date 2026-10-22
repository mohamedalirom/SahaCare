import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/appointments/orientation/domain/emergency_detector.dart';

void main() {
  group('EmergencyDetector', () {
    test('détecte les urgences médicales en français avec et sans accents', () {
      final r1 = EmergencyDetector.analyze(
          "J'ai une forte douleur thoracique et une oppression depuis 20 minutes");
      expect(r1.isEmergency, isTrue);
      expect(r1.isSuicidal, isFalse);

      final r2 = EmergencyDetector.analyze(
          "difficulte a respirer et etouffement apres repas");
      expect(r2.isEmergency, isTrue);

      final r3 = EmergencyDetector.analyze(
          "Mon mari a eu une perte de connaissance soudaine");
      expect(r3.isEmergency, isTrue);

      final r4 = EmergencyDetector.analyze(
          "faiblesse soudaine d'un côté du corps et difficulte a parler");
      expect(r4.isEmergency, isTrue);

      final r5 = EmergencyDetector.analyze("convulsions violentes chez mon fils");
      expect(r5.isEmergency, isTrue);

      final r6 = EmergencyDetector.analyze(
          "choc anaphylactique et gonflement de la gorge");
      expect(r6.isEmergency, isTrue);
    });

    test('détecte les urgences médicales en anglais', () {
      final r1 = EmergencyDetector.analyze(
          "I have sudden severe chest pain and heart attack symptoms");
      expect(r1.isEmergency, isTrue);

      final r2 = EmergencyDetector.analyze(
          "Severe shortness of breath and cannot breathe");
      expect(r2.isEmergency, isTrue);

      final r3 = EmergencyDetector.analyze(
          "He fainted and had a sudden seizure");
      expect(r3.isEmergency, isTrue);
    });

    test('détecte les urgences médicales en arabe (avec ou sans diacritiques)', () {
      final r1 = EmergencyDetector.analyze("أشعر بألم في الصدر وضيق في التنفس");
      expect(r1.isEmergency, isTrue);

      final r2 = EmergencyDetector.analyze("إغماء مفاجئ وتشنجات");
      expect(r2.isEmergency, isTrue);

      final r3 = EmergencyDetector.analyze("نزيف حاد مستمر");
      expect(r3.isEmergency, isTrue);
    });

    test('détecte les signaux de détresse suicidaire avec le flag isSuicidal', () {
      final r1 = EmergencyDetector.analyze(
          "Je n'en peux plus, j'ai des pensées suicidaires et envie d'en finir");
      expect(r1.isEmergency, isTrue);
      expect(r1.isSuicidal, isTrue);

      final r2 = EmergencyDetector.analyze("I want to die, having suicidal thoughts");
      expect(r2.isEmergency, isTrue);
      expect(r2.isSuicidal, isTrue);

      final r3 = EmergencyDetector.analyze("لدي أفكار انتحارية وأريد الموت");
      expect(r3.isEmergency, isTrue);
      expect(r3.isSuicidal, isTrue);
    });

    test('ne déclenche PAS l alerte sur des symptômes bénins ou ordinaires', () {
      final benignPhrases = [
        "J'ai un peu mal au dos depuis hier après avoir porté un carton",
        "Éruption cutanée légère qui gratte un peu sur le coude",
        "Besoin de refaire mes lunettes, ma vue baisse légèrement",
        "Sensibilité dentaire au froid sur une molaire",
        "Je voudrais un contrôle de routine chez le généraliste",
        "Fatigue passagère après une longue semaine de travail",
        "Routine eye checkup for driving license",
        "فحص روتيني للأسنان وتنظيف الجير",
      ];

      for (final phrase in benignPhrases) {
        final result = EmergencyDetector.analyze(phrase);
        expect(
          result.isEmergency,
          isFalse,
          reason: 'A déclenché à tort sur: "$phrase"',
        );
      }
    });

    test('gère correctement les textes vides ou blancs', () {
      expect(EmergencyDetector.analyze("").isEmergency, isFalse);
      expect(EmergencyDetector.analyze("   ").isEmergency, isFalse);
    });
  });
}
