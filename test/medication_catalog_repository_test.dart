import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sahacare/features/medications/data/medication_catalog_repository.dart';
import 'package:sahacare/features/medications/data/services/medication_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads the dated offline catalog with the requested common brands',
    () async {
      var networkRequests = 0;
      final service = MedicationSearchService(
        client: MockClient((_) async {
          networkRequests++;
          return http.Response('{}', 200);
        }),
      );
      final repository = DefaultMedicationCatalogRepository(
        searchService: service,
      );

      final initialSuggestions = await repository.searchLocal('');
      expect(initialSuggestions, hasLength(9));
      expect(initialSuggestions.map((item) => item.name), [
        'Doliprane',
        'Efferalgan',
        'Panadol',
        'Dafalgan',
        'Advil',
        'Spasfon',
        'Augmentin',
        'Amoxil',
        'Amoxicilline Almus',
      ]);
      expect(networkRequests, 0);

      final partialBrand = await repository.searchLocal('doli');
      expect(partialBrand.map((item) => item.name), ['Doliprane']);
      expect(partialBrand.single.activeIngredient, 'Paracétamol');

      final accentedIngredient = await repository.searchLocal('PARACÉTAMOL');
      expect(accentedIngredient.map((item) => item.name), [
        'Doliprane',
        'Efferalgan',
        'Panadol',
        'Dafalgan',
      ]);
      expect((await repository.searchLocal('amox')).map((item) => item.name), [
        'Augmentin',
        'Amoxil',
        'Amoxicilline Almus',
      ]);
      expect((await repository.searchLocal('adv')).single.name, 'Advil');
      expect(networkRequests, 0);
      service.close();
    },
  );

  test(
    'local results are still available when the online service is offline',
    () async {
      final repository = DefaultMedicationCatalogRepository(
        searchService: MedicationSearchService(
          client: MockClient((_) async => throw Exception('offline')),
        ),
      );

      expect((await repository.searchLocal('doli')).single.name, 'Doliprane');
      await expectLater(
        repository.searchOnline('doli'),
        throwsA(isA<Exception>()),
      );
      expect((await repository.searchLocal('doli')).single.name, 'Doliprane');
    },
  );

  test('surfaces a malformed local catalog instead of hiding the error', () {
    final repository = DefaultMedicationCatalogRepository(
      assetBundle: _StringAssetBundle('{"medications": "invalid"}'),
      searchService: MedicationSearchService(
        client: MockClient((_) async {
          return http.Response(jsonEncode({}), 200);
        }),
      ),
    );

    expect(repository.searchLocal(''), throwsFormatException);
  });
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.value);

  final String value;

  @override
  Future<ByteData> load(String key) async {
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async => value;
}
