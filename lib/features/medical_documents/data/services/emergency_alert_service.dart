import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../appointments/nearby/data/datasources/location_service.dart';

/// Numéro du SAMU en Tunisie
const String samuNumber = '190';

/// Position envoyée dans l'alerte
class AlertLocation {
  final double latitude;
  final double longitude;

  /// Précision en mètres (null si inconnue)
  final double? accuracy;

  const AlertLocation({required this.latitude, required this.longitude, this.accuracy});

  factory AlertLocation.fromPosition(Position p) =>
      AlertLocation(latitude: p.latitude, longitude: p.longitude, accuracy: p.accuracy);

  /// Lien ouvrable sur n'importe quel téléphone (Google Maps, navigateur…)
  String get mapsLink =>
      'https://maps.google.com/?q=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
}

/// Bouton SOS : récupère la position et prépare le SMS d'alerte ou l'appel au SAMU.
class EmergencyAlertService {
  final LocationService _location;
  final Future<bool> Function(Uri uri) _launch;

  EmergencyAlertService({LocationService? location, Future<bool> Function(Uri uri)? launcher})
    : _location = location ?? LocationService(),
      _launch = launcher ?? ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  /// L'envoi direct de SMS n'existe que sur téléphone (pas sur le web ni l'ordinateur)
  bool get canSendSms =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Position actuelle ; lève [LocationCustomException] si GPS coupé ou permission refusée
  Future<AlertLocation> currentLocation() async =>
      AlertLocation.fromPosition(await _location.getCurrentPosition());

  Future<bool> openLocationSettings() => _location.openLocationSettings();

  Future<bool> openAppSettings() => _location.openAppSettings();

  /// Texte de l'alerte : identité, position (ou son absence) et infos vitales utiles aux secours
  static String buildMessage({
    String? senderName,
    AlertLocation? location,
    String? bloodGroup,
    List<String> allergies = const [],
  }) {
    final who = (senderName == null || senderName.trim().isEmpty) ? 'Je' : senderName.trim();
    final lines = <String>[
      'URGENCE SahaCare : ${who == 'Je' ? 'j\'ai' : '$who a'} besoin d\'aide.',
      if (location != null) ...[
        'Ma position : ${location.mapsLink}',
        if (location.accuracy != null) 'Précision : environ ${location.accuracy!.round()} m',
      ] else
        'Position indisponible, appelez-moi.',
      if (bloodGroup != null && bloodGroup.trim().isNotEmpty) 'Groupe sanguin : ${bloodGroup.trim()}',
      if (allergies.isNotEmpty) 'Allergies : ${allergies.join(', ')}',
      'SAMU : $samuNumber',
    ];
    return lines.join('\n');
  }

  /// URI SMS multi-destinataires (format iOS ou Android), corps encodé en %20 et non en "+"
  static Uri smsUri(List<String> phones, String body, {TargetPlatform? platform}) {
    final recipients = phones.map((p) => p.replaceAll(RegExp(r'[^0-9+]'), '')).where((p) => p.isNotEmpty);
    final encodedBody = Uri.encodeComponent(body);
    if ((platform ?? defaultTargetPlatform) == TargetPlatform.iOS) {
      return Uri.parse('sms:/open?addresses=${recipients.join(',')}&body=$encodedBody');
    }
    return Uri.parse('sms:${recipients.join(',')}?body=$encodedBody');
  }

  /// Ouvre l'application SMS avec le message prêt ; l'utilisateur n'a plus qu'à appuyer sur Envoyer
  Future<bool> sendSms(List<String> phones, String body) => _launch(smsUri(phones, body));

  Future<bool> call(String number) => _launch(Uri(scheme: 'tel', path: number));
}
