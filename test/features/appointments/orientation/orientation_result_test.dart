import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/appointments/orientation/domain/entities/orientation_result.dart';

void main() {
  group('OrientationResult Parsing & Model', () {
    test('parse un JSON valide avec spécialités et urgence routine', () {
      final json = {
        'recommended_specialties': [
          {
            'name': 'Dermatologie',
            'reason': 'Lésions cutanées avec prurit',
            'confidence': 'high',
          },
          {
            'name': 'Médecine Générale',
            'reason': 'Évaluation générale recommandée',
            'confidence': 'medium',
          }
        ],
        'urgency': 'routine',
        'needs_more_info': false,
        'advice': 'Évitez de gratter les lésions.',
      };

      final result = OrientationResult.fromJson(json);

      expect(result.recommendedSpecialties.length, equals(2));
      expect(result.recommendedSpecialties[0].name, equals('Dermatologie'));
      expect(result.recommendedSpecialties[0].confidence, equals('high'));
      expect(result.recommendedSpecialties[1].name, equals('Médecine Générale'));
      expect(result.urgency, equals('routine'));
      expect(result.needsMoreInfo, isFalse);
      expect(result.clarificationQuestion, isNull);
      expect(result.advice, equals('Évitez de gratter les lésions.'));
      expect(result.isDegradedMode, isFalse);
    });

    test('parse correctement une demande de clarification', () {
      final json = {
        'recommended_specialties': [],
        'urgency': 'routine',
        'needs_more_info': true,
        'clarification_question':
            'Depuis combien de temps ressentez-vous cette gêne ?',
        'advice': 'Veuillez préciser la durée de vos symptômes.',
      };

      final result = OrientationResult.fromJson(json);

      expect(result.recommendedSpecialties, isEmpty);
      expect(result.needsMoreInfo, isTrue);
      expect(result.clarificationQuestion,
          equals('Depuis combien de temps ressentez-vous cette gêne ?'));
    });

    test('parse correctement le niveau urgency emergency', () {
      final json = {
        'recommended_specialties': [
          {
            'name': 'Cardiologie',
            'reason': 'Suspicion de problème aigu',
            'confidence': 'high',
          }
        ],
        'urgency': 'emergency',
        'needs_more_info': false,
        'advice': 'Contactez sans attendre les urgences au 190.',
      };

      final result = OrientationResult.fromJson(json);

      expect(result.urgency, equals('emergency'));
      expect(result.recommendedSpecialties.first.name, equals('Cardiologie'));
    });

    test('gère les champs manquants avec des valeurs par défaut sûres', () {
      final json = <String, dynamic>{};
      final result = OrientationResult.fromJson(json);

      expect(result.recommendedSpecialties, isEmpty);
      expect(result.urgency, equals('routine'));
      expect(result.needsMoreInfo, isFalse);
      expect(result.clarificationQuestion, isNull);
      expect(result.advice, isEmpty);
    });

    test('sérialise et désérialise en JSON de façon symétrique', () {
      const original = OrientationResult(
        recommendedSpecialties: [
          RecommendedSpecialty(
            name: 'Pédiatrie',
            reason: 'Enfant en bas âge',
            confidence: 'high',
          ),
        ],
        urgency: 'soon',
        needsMoreInfo: false,
        clarificationQuestion: null,
        advice: 'Surveillez la température.',
        isDegradedMode: true,
      );

      final map = original.toJson();
      final reconstructed = OrientationResult.fromJson(map, isDegradedMode: true);

      expect(reconstructed, equals(original));
    });
  });
}
