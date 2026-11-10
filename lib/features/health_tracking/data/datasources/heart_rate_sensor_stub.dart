import 'heart_rate_sensor.dart';

/// Hors navigateur (mobile, bureau, tests) : pas de Web Bluetooth
class _UnsupportedHeartRateSensor implements HeartRateSensor {
  @override
  bool get isSupported => false;

  @override
  bool get isConnected => false;

  @override
  Future<String> connect() => throw UnsupportedError('Bluetooth disponible uniquement dans le navigateur.');

  @override
  void disconnect() {}

  @override
  List<double> drain() => const [];
}

HeartRateSensor createHeartRateSensor() => _UnsupportedHeartRateSensor();
