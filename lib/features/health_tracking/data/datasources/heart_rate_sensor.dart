import 'heart_rate_sensor_stub.dart' if (dart.library.js_interop) 'heart_rate_sensor_web.dart' as impl;

/// Capteur de fréquence cardiaque Bluetooth (profil standard « Heart Rate »),
/// lu avec l'API Web Bluetooth du navigateur (web/saha_watch.js).
/// Une Apple Watch est vue comme un tel capteur via une application de diffusion.
abstract class HeartRateSensor {
  /// Bluetooth utilisable dans ce navigateur (Chrome ou Edge sur ordinateur)
  bool get isSupported;

  /// false si le capteur s'est déconnecté
  bool get isConnected;

  /// Ouvre le sélecteur d'appareils du navigateur. Renvoie le nom du capteur.
  Future<String> connect();

  void disconnect();

  /// Valeurs (bpm) reçues depuis le dernier appel
  List<double> drain();
}

HeartRateSensor createHeartRateSensor() => impl.createHeartRateSensor();
