import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sahacare/features/medications/data/services/medication_search_service.dart';

void main() {
  test(
    'searches a partial name and returns verified product details',
    () async {
      Uri? approximateUri;
      final service = MedicationSearchService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/approximateTerm.json')) {
            approximateUri = request.url;
            return http.Response(
              jsonEncode({
                'approximateGroup': {
                  'candidate': [
                    {
                      'rxcui': '161',
                      'name': 'paracetamol',
                      'source': 'DRUGBANK',
                    },
                  ],
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/rxcui/161/properties.json')) {
            return http.Response(
              jsonEncode({
                'properties': {
                  'rxcui': '161',
                  'name': 'acetaminophen',
                  'tty': 'IN',
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/drugs.json')) {
            expect(request.url.queryParameters['name'], 'acetaminophen');
            return http.Response(
              jsonEncode({
                'drugGroup': {
                  'conceptGroup': [
                    {
                      'tty': 'SCD',
                      'conceptProperties': [
                        {
                          'rxcui': '198440',
                          'name': 'acetaminophen 500 MG Oral Tablet',
                          'tty': 'SCD',
                          'suppress': 'N',
                        },
                      ],
                    },
                  ],
                },
              }),
              200,
            );
          }
          throw StateError('Unexpected RxNorm endpoint: ${request.url}');
        }),
      );

      final results = await service.search('Para');

      expect(approximateUri?.queryParameters, {
        'term': 'Para',
        'maxEntries': '10',
        'option': '1',
      });
      expect(results, hasLength(1));
      expect(results.single.name, 'acetaminophen');
      expect(results.single.activeIngredient, 'acetaminophen');
      expect(results.single.presentations, ['500 MG • Oral Tablet']);
    },
  );

  test(
    'returns an empty list when RxNorm has no matching candidates',
    () async {
      final service = MedicationSearchService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'approximateGroup': {'candidate': []},
            }),
            200,
          ),
        ),
      );

      expect(await service.search('zzq'), isEmpty);
    },
  );

  test(
    'searches a brand and returns its verified ingredient and presentations',
    () async {
      final service = MedicationSearchService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/approximateTerm.json')) {
            return http.Response(
              jsonEncode({
                'approximateGroup': {
                  'candidate': [
                    {'rxcui': '153010', 'name': 'Advil', 'source': 'RXNORM'},
                  ],
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/rxcui/153010/properties.json')) {
            return http.Response(
              jsonEncode({
                'properties': {
                  'rxcui': '153010',
                  'name': 'Advil',
                  'tty': 'BN',
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/rxcui/153010/related.json')) {
            return http.Response(
              jsonEncode({
                'relatedGroup': {
                  'conceptGroup': [
                    {
                      'tty': 'IN',
                      'conceptProperties': [
                        {'rxcui': '5640', 'name': 'ibuprofen'},
                      ],
                    },
                  ],
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/drugs.json')) {
            return http.Response(
              jsonEncode({
                'drugGroup': {
                  'conceptGroup': [
                    {
                      'tty': 'SBD',
                      'conceptProperties': [
                        {
                          'rxcui': '197806',
                          'name': 'ibuprofen 200 MG Oral Tablet [Advil]',
                          'suppress': 'N',
                        },
                        {
                          'rxcui': '197804',
                          'name': 'ibuprofen 200 MG Oral Capsule [Advil]',
                          'suppress': 'N',
                        },
                      ],
                    },
                  ],
                },
              }),
              200,
            );
          }
          throw StateError('Unexpected RxNorm endpoint: ${request.url}');
        }),
      );

      final results = await service.search('adv');

      expect(results, hasLength(1));
      expect(results.single.name, 'Advil');
      expect(results.single.activeIngredient, 'ibuprofen');
      expect(results.single.presentations, [
        '200 MG • Oral Tablet',
        '200 MG • Oral Capsule',
      ]);
    },
  );

  test('surfaces RxNorm network and HTTP errors', () async {
    final service = MedicationSearchService(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );

    await expectLater(service.search('Para'), throwsA(isA<Exception>()));
  });

  test('does not request the catalog for fewer than two characters', () async {
    var requestCount = 0;
    final service = MedicationSearchService(
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );

    expect(await service.search('P'), isEmpty);
    expect(requestCount, 0);
  });
}
