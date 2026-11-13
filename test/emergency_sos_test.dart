import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sahacare/features/appointments/nearby/data/datasources/location_service.dart';
import 'package:sahacare/features/medical_documents/data/services/emergency_alert_service.dart';
import 'package:sahacare/features/medical_documents/presentation/providers/medical_documents_providers.dart';
import 'package:sahacare/features/medical_documents/presentation/screens/emergency_sos_page.dart';

class _FakeLocation extends LocationService {
  final Position? position;
  _FakeLocation(this.position);

  @override
  Future<Position> getCurrentPosition({Duration timeout = const Duration(seconds: 12)}) async {
    if (position == null) {
      throw const LocationCustomException('La permission de localisation a été refusée.',
          LocationErrorType.permissionDenied);
    }
    return position!;
  }
}

Position _position(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026, 11, 13),
  accuracy: 12,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Future<List<Uri>> _pumpSos(WidgetTester tester, {Position? position}) async {
  final launched = <Uri>[];
  final service = EmergencyAlertService(
    location: _FakeLocation(position),
    launcher: (uri) async {
      launched.add(uri);
      return true;
    },
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [emergencyAlertServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: EmergencySosPage()),
    ),
  );
  await tester.pumpAndSettle();
  return launched;
}

void main() {
  group('Message et SMS', () {
    test('le message contient le lien Google Maps, le groupe sanguin et le SAMU', () {
      final message = EmergencyAlertService.buildMessage(
        senderName: 'Amira Ben Salah',
        location: const AlertLocation(latitude: 36.8065, longitude: 10.1815, accuracy: 8),
        bloodGroup: 'O+',
        allergies: ['Pénicilline'],
      );
      expect(message, contains('Amira Ben Salah a besoin d\'aide'));
      expect(message, contains('https://maps.google.com/?q=36.806500,10.181500'));
      expect(message, contains('Groupe sanguin : O+'));
      expect(message, contains('Allergies : Pénicilline'));
      expect(message, contains('SAMU : 190'));
    });

    test('sans position, le message le dit', () {
      final message = EmergencyAlertService.buildMessage();
      expect(message, contains('Position indisponible'));
      expect(message, isNot(contains('maps.google.com')));
    });

    test('URI SMS : plusieurs destinataires, espaces encodés en %20', () {
      final android = EmergencyAlertService.smsUri(
        ['+216 98 123 456', '22 333 444'],
        'Au secours ici',
        platform: TargetPlatform.android,
      );
      expect(android.toString(), 'sms:+21698123456,22333444?body=Au%20secours%20ici');

      final ios = EmergencyAlertService.smsUri(['+21698123456'], 'Aide', platform: TargetPlatform.iOS);
      expect(ios.toString(), 'sms:/open?addresses=+21698123456&body=Aide');
    });
  });

  group('Écran SOS', () {
    testWidgets('position trouvée : le SMS part vers les contacts avec le lien', (tester) async {
      final launched = await _pumpSos(tester, position: _position(36.8065, 10.1815));

      expect(find.text('Position trouvée'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Envoyer ma position par SMS'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Envoyer ma position par SMS'));
      await tester.pump();

      expect(launched, hasLength(1));
      final sms = launched.single.toString();
      expect(sms, startsWith('sms:'));
      expect(Uri.decodeComponent(sms), contains('https://maps.google.com/?q=36.806500,10.181500'));
    });

    testWidgets('permission refusée : alerte possible sans position, appel SAMU', (tester) async {
      final launched = await _pumpSos(tester);

      expect(find.text('Position indisponible'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Envoyer ma position par SMS'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Envoyer ma position par SMS'));
      await tester.pump();
      expect(Uri.decodeComponent(launched.last.toString()), contains('Position indisponible'));

      await tester.scrollUntilVisible(find.text('Appeler le SAMU (190)'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Appeler le SAMU (190)'));
      await tester.pump();
      expect(launched.last, Uri(scheme: 'tel', path: '190'));
    });
  });
}
