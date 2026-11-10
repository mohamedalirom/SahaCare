import 'dart:convert';
import 'dart:js_interop';

import 'heart_rate_sensor.dart';

@JS('sahaWatch')
external _SahaWatch? get _sahaWatch;

extension type _SahaWatch._(JSObject _) implements JSObject {
  external bool supported();
  external String state();
  external JSPromise<JSString> connect();
  external void disconnect();
  external String drain();
}

class _WebHeartRateSensor implements HeartRateSensor {
  @override
  bool get isSupported => _sahaWatch?.supported() ?? false;

  @override
  bool get isConnected {
    final watch = _sahaWatch;
    if (watch == null) return false;
    return (jsonDecode(watch.state()) as Map<String, dynamic>)['status'] == 'connected';
  }

  @override
  Future<String> connect() async => (await _sahaWatch!.connect().toDart).toDart;

  @override
  void disconnect() => _sahaWatch?.disconnect();

  @override
  List<double> drain() {
    final watch = _sahaWatch;
    if (watch == null) return const [];
    return (jsonDecode(watch.drain()) as List).map((v) => (v as num).toDouble()).toList();
  }
}

HeartRateSensor createHeartRateSensor() => _WebHeartRateSensor();
