import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sahacare/features/appointments/nearby/data/datasources/overpass_service.dart';
import 'package:sahacare/features/appointments/nearby/domain/entities/nearby_place.dart';
import 'package:sahacare/features/appointments/nearby/domain/specialty_mapper.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('1. Construction de la requête Overpass et arrondi des coordonnées', () {
    final service = OverpassService();

    test('Arrondit les coordonnées à 3 décimales pour la confidentialité', () {
      expect(OverpassService.roundCoordinate(35.82561234), 35.826);
      expect(OverpassService.roundCoordinate(10.63699123), 10.637);
      expect(OverpassService.roundCoordinate(36.8064999), 36.806);
    });

    test('Construit la requête Overpass avec rayon et coordonnées arrondies', () {
      final query = service.buildOverpassQuery(
        roundedLat: 35.826,
        roundedLon: 10.637,
        radiusMeters: 3000,
      );

      expect(query, contains('[out:json][timeout:25];'));
      expect(query, contains('(around:3000,35.826,10.637)'));
      expect(query, contains('amenity"~"^(doctors|clinic|hospital|dentist|pharmacy)\$"'));
      expect(query, contains('nwr["healthcare"]'));
      expect(query, contains('out center tags 60;'));
    });
  });

  group('2. Mapping des spécialités OSM vers spécialités SahaCare', () {
    test('Mappe correctement les spécialités courantes', () {
      expect(SpecialtyMapper.mapSpecialty('cardiology'), 'Cardiologie');
      expect(SpecialtyMapper.mapSpecialty('cardiologist'), 'Cardiologie');
      expect(SpecialtyMapper.mapSpecialty('dermatology'), 'Dermatologie');
      expect(SpecialtyMapper.mapSpecialty('paediatrics'), 'Pédiatrie');
      expect(SpecialtyMapper.mapSpecialty('pediatrics'), 'Pédiatrie');
      expect(SpecialtyMapper.mapSpecialty('general'), 'Médecine Générale');
      expect(SpecialtyMapper.mapSpecialty('general_practitioner'), 'Médecine Générale');
      expect(SpecialtyMapper.mapSpecialty('dentist'), 'Dentiste');
      expect(SpecialtyMapper.mapSpecialty('ophthalmology'), 'Ophtalmologie');
      expect(SpecialtyMapper.mapSpecialty('gynecology'), 'Gynécologie');
      expect(SpecialtyMapper.mapSpecialty('neurology'), 'Neurologie');
      expect(SpecialtyMapper.mapSpecialty('orthopaedics'), 'Orthopédie');
      expect(SpecialtyMapper.mapSpecialty('psychiatry'), 'Psychiatrie');
    });

    test('Mappe l\'amenity si specialty est absente', () {
      expect(SpecialtyMapper.mapSpecialty(null, amenity: 'dentist'), 'Dentiste');
      expect(SpecialtyMapper.mapSpecialty('', amenity: 'pharmacy'), 'Pharmacie');
      expect(SpecialtyMapper.mapSpecialty(null, amenity: 'doctors'), '');
    });
  });

  group('3. Parsing de réponse Overpass (JSON fixe)', () {
    final service = OverpassService();
    const userLat = 35.8256;
    const userLon = 10.63699;

    const sampleJson = '''
    {
      "elements": [
        {
          "type": "node",
          "id": 101,
          "lat": 35.8260,
          "lon": 10.6375,
          "tags": {
            "name": "Dr. Mohamed Triki",
            "amenity": "doctors",
            "healthcare:speciality": "cardiology",
            "phone": "+216 73 111 222",
            "addr:street": "Avenue Habib Bourguiba",
            "addr:housenumber": "12",
            "addr:city": "Sousse"
          }
        },
        {
          "type": "way",
          "id": 202,
          "center": {
            "lat": 35.8300,
            "lon": 10.6400
          },
          "tags": {
            "name": "Clinique Les Oliviers",
            "amenity": "clinic",
            "contact:phone": "+216 73 333 444",
            "contact:website": "https://clinique-oliviers.tn"
          }
        },
        {
          "type": "node",
          "id": 303,
          "lat": 35.8240,
          "lon": 10.6350,
          "tags": {
            "amenity": "pharmacy"
          }
        },
        {
          "type": "node",
          "id": 404,
          "tags": {
            "name": "Établissement sans coordonnées",
            "amenity": "hospital"
          }
        },
        {
          "type": "node",
          "id": 101,
          "lat": 35.8260,
          "lon": 10.6375,
          "tags": {
            "name": "Dr. Mohamed Triki Doublon",
            "amenity": "doctors"
          }
        }
      ]
    }
    ''';

    test('Parse correctement node, way avec center, remplace les noms manquants et élimine sans coords et doublons', () {
      final places = service.parseOverpassResponse(
        responseBody: sampleJson,
        userLat: userLat,
        userLon: userLon,
      );

      // Doit contenir 3 éléments valides (101, 202, 303), 404 ignoré sans coords, doublon 101 éliminé
      expect(places.length, 3);

      // 1. Node médecin
      final doctor = places.firstWhere((p) => p.id == 'node_101');
      expect(doctor.name, 'Dr. Mohamed Triki');
      expect(doctor.category, NearbyCategory.doctor);
      expect(doctor.mappedSpecialty, 'Cardiologie');
      expect(doctor.phone, '+216 73 111 222');
      expect(doctor.address, contains('12, Avenue Habib Bourguiba, Sousse'));
      expect(doctor.distanceInMeters, greaterThan(0));

      // 2. Way clinique avec center
      final clinic = places.firstWhere((p) => p.id == 'way_202');
      expect(clinic.name, 'Clinique Les Oliviers');
      expect(clinic.category, NearbyCategory.clinic);
      expect(clinic.latitude, 35.8300);
      expect(clinic.longitude, 10.6400);
      expect(clinic.website, 'https://clinique-oliviers.tn');

      // 3. Pharmacie sans nom -> libellé par défaut
      final pharmacy = places.firstWhere((p) => p.id == 'node_303');
      expect(pharmacy.name, 'Pharmacie de proximité');
      expect(pharmacy.category, NearbyCategory.pharmacy);
    });

    test('Trie les lieux par distance croissante', () {
      final places = service.parseOverpassResponse(
        responseBody: sampleJson,
        userLat: userLat,
        userLon: userLon,
      );

      for (int i = 0; i < places.length - 1; i++) {
        expect(places[i].distanceInMeters, lessThanOrEqualTo(places[i + 1].distanceInMeters));
      }
    });

    test('Lève une OverpassException si le JSON est invalide', () {
      expect(
        () => service.parseOverpassResponse(
          responseBody: 'Not a JSON',
          userLat: userLat,
          userLon: userLon,
        ),
        throwsA(isA<OverpassException>()),
      );
    });
  });

  group('4. Gestion des erreurs HTTP et du réseau avec mocktail', () {
    late MockHttpClient mockClient;
    late OverpassService serviceWithMock;

    setUp(() {
      mockClient = MockHttpClient();
      serviceWithMock = OverpassService(client: mockClient);
    });

    test('Gère les erreurs 429 Rate Limit avec retry et exception', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Too Many Requests', 429));

      expect(
        () => serviceWithMock.fetchNearbyPlaces(userLat: 35.82, userLon: 10.63, radiusMeters: 3000),
        throwsA(isA<OverpassException>()),
      );
    });

    test('Gère les réponses 200 vides correctement', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('{"elements": []}', 200));

      final result = await serviceWithMock.fetchNearbyPlaces(
        userLat: 35.82,
        userLon: 10.63,
        radiusMeters: 3000,
      );

      expect(result, isEmpty);
    });

    test('Gère les erreurs 504 Gateway Timeout', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Gateway Timeout', 504));

      expect(
        () => serviceWithMock.fetchNearbyPlaces(userLat: 35.82, userLon: 10.63, radiusMeters: 3000),
        throwsA(isA<OverpassException>()),
      );
    });
  });
}
