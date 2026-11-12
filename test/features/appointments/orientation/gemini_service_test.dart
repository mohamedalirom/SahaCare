import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sahacare/features/appointments/orientation/data/datasources/gemini_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('GeminiService', () {
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
    });

    test('lève GeminiKeyMissingException si aucune clé API n est fournie', () async {
      final service = GeminiService(client: mockClient, apiKeyOverride: '');
      expect(
        () => service.orientSymptoms(
          symptomsText: "J'ai mal au dos",
          allowedSpecialties: ['Orthopédie'],
        ),
        throwsA(isA<GeminiKeyMissingException>()),
      );
    });

    test('retourne le JSON parsé lors d un appel réussi 200 OK', () async {
      final service = GeminiService(
        client: mockClient,
        apiKeyOverride: 'AIzaSyFakeKeyForTest123456789',
      );

      final geminiResponsePayload = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'recommended_specialties': [
                      {
                        'name': 'Dermatologie',
                        'reason': 'Plaques rouges et démangeaisons',
                        'confidence': 'high',
                      }
                    ],
                    'urgency': 'routine',
                    'needs_more_info': false,
                    'advice': 'Consultez un dermatologue.',
                  })
                }
              ]
            },
            'finishReason': 'STOP',
          }
        ]
      };

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode(geminiResponsePayload),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      final result = await service.orientSymptoms(
        symptomsText: "J'ai des rougeurs sur la peau qui démangent",
        allowedSpecialties: ['Dermatologie', 'Médecine Générale'],
      );

      expect(result['urgency'], equals('routine'));
      expect(result['recommended_specialties'], isList);
      final specs = result['recommended_specialties'] as List;
      expect(specs.first['name'], equals('Dermatologie'));
    });

    test('lève GeminiAuthException sur code 401 ou 403', () async {
      final service = GeminiService(
        client: mockClient,
        apiKeyOverride: 'bad_key',
      );

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('{"error": "API_KEY_INVALID"}', 403));

      expect(
        () => service.orientSymptoms(
          symptomsText: "J'ai mal aux dents",
          allowedSpecialties: ['Dentiste'],
        ),
        throwsA(isA<GeminiAuthException>()),
      );
    });

    test('lève GeminiQuotaException sur code 429', () async {
      final service = GeminiService(
        client: mockClient,
        apiKeyOverride: 'valid_key',
      );

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('{"error": "RESOURCE_EXHAUSTED"}', 429));

      expect(
        () => service.orientSymptoms(
          symptomsText: "J'ai mal aux dents",
          allowedSpecialties: ['Dentiste'],
        ),
        throwsA(isA<GeminiQuotaException>()),
      );
    });

    test('lève GeminiServerException sur code 500', () async {
      final service = GeminiService(
        client: mockClient,
        apiKeyOverride: 'valid_key',
      );

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('Server Error', 500));

      expect(
        () => service.orientSymptoms(
          symptomsText: "J'ai mal aux dents",
          allowedSpecialties: ['Dentiste'],
        ),
        throwsA(isA<GeminiServerException>()),
      );
    });

    test('lève GeminiSafetyException si le filtre de sécurité bloque la réponse', () async {
      final service = GeminiService(
        client: mockClient,
        apiKeyOverride: 'valid_key',
      );

      final blockedPayload = {
        'candidates': [
          {
            'finishReason': 'SAFETY',
          }
        ]
      };

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response(jsonEncode(blockedPayload), 200));

      expect(
        () => service.orientSymptoms(
          symptomsText: "Texte sensible",
          allowedSpecialties: ['Médecine Générale'],
        ),
        throwsA(isA<GeminiSafetyException>()),
      );
    });

    test('retente une fois en cas d exception réseau puis lève GeminiNetworkException', () async {
      final service = GeminiService(
        client: mockClient,
        apiKeyOverride: 'valid_key',
      );

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenThrow(const SocketException('Failed to host lookup'));

      expect(
        () => service.orientSymptoms(
          symptomsText: "J'ai mal aux dents",
          allowedSpecialties: ['Dentiste'],
        ),
        throwsA(isA<GeminiNetworkException>()),
      );

      verify(() => mockClient.post(any(),
          headers: any(named: 'headers'), body: any(named: 'body'))).called(2);
    });
  });
}
