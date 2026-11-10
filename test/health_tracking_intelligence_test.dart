import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sahacare/features/health_tracking/data/datasources/health_measurement_local_datasource.dart';
import 'package:sahacare/features/health_tracking/data/datasources/heart_rate_sensor.dart';
import 'package:sahacare/features/health_tracking/data/datasources/hugging_face_service.dart';
import 'package:sahacare/features/health_tracking/data/models/health_measurement_model.dart';
import 'package:sahacare/features/health_tracking/domain/entities/health_insight.dart';
import 'package:sahacare/features/health_tracking/domain/entities/health_measurement.dart';
import 'package:sahacare/features/health_tracking/domain/services/health_analysis_engine.dart';
import 'package:sahacare/features/health_tracking/domain/services/insight_text_guard.dart';
import 'package:sahacare/features/health_tracking/presentation/controllers/health_tracking_controller.dart';
import 'package:sahacare/features/health_tracking/presentation/controllers/saha_intelligence_controller.dart';

final _now = DateTime(2026, 11, 10, 12);

int _id = 0;

HealthMeasurement _m(MeasurementType type, double value, int daysAgo, {double? secondary}) => HealthMeasurement(
  id: 'm${_id++}',
  type: type,
  value: value,
  secondaryValue: secondary,
  dateTime: _now.subtract(Duration(days: daysAgo, hours: 1)),
);

/// Fréquence cardiaque régulière autour de 70 bpm, une mesure tous les 3 jours
List<HealthMeasurement> _steadyHeartRate({double? latest}) => [
  for (int i = 10; i >= 1; i--) _m(MeasurementType.heartRate, i.isEven ? 68 : 72, i * 3),
  if (latest != null) _m(MeasurementType.heartRate, latest, 0),
];

class _InMemoryDataSource implements HealthMeasurementLocalDataSource {
  final Map<String, HealthMeasurementModel> rows;

  _InMemoryDataSource(List<HealthMeasurement> initial)
    : rows = {for (final m in initial) m.id: HealthMeasurementModel.fromEntity(m)};

  @override
  Future<List<HealthMeasurementModel>> getMeasurements(String userId) async =>
      rows.values.toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  @override
  Future<void> insertMeasurement(String userId, HealthMeasurementModel m) async => rows[m.id] = m;

  @override
  Future<void> updateMeasurement(String userId, HealthMeasurementModel m) async => rows[m.id] = m;

  @override
  Future<void> deleteMeasurement(String userId, String id) async => rows.remove(id);
}

/// Capteur Bluetooth factice : les valeurs sont injectées par le test
class _FakeSensor implements HeartRateSensor {
  final List<double> pending = [];
  bool connected = false;
  bool fail = false;

  @override
  bool get isSupported => true;

  @override
  bool get isConnected => connected;

  @override
  Future<String> connect() async {
    if (fail) throw Exception('aucun capteur choisi');
    connected = true;
    return 'Apple Watch';
  }

  @override
  void disconnect() => connected = false;

  @override
  List<double> drain() {
    final values = [...pending];
    pending.clear();
    return values;
  }
}

http.Response _hfAnswer(String content) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'choices': [
        {
          'message': {'role': 'assistant', 'content': content},
        },
      ],
    }),
  ),
  200,
);

void main() {
  const engine = HealthAnalysisEngine();

  group('Moteur d\'analyse', () {
    test('statistiques et régression linéaire', () {
      expect(HealthAnalysisEngine.mean([2, 4, 6]), 4);
      expect(HealthAnalysisEngine.stdDev([2, 4, 6]), 2);
      final fit = HealthAnalysisEngine.linearRegression([0, 1, 2, 3], [1, 3, 5, 7])!;
      expect(fit.slope, closeTo(2, 1e-9));
      expect(fit.intercept, closeTo(1, 1e-9));
    });

    test('une valeur dans les normes générales peut être inhabituelle pour la personne', () {
      // 95 bpm est « normal » (60–100) mais très loin des 70 bpm habituels
      final insight = engine.analyze(_steadyHeartRate(latest: 95), now: _now).insights.single;
      expect(insight.latest.status, MeasurementStatus.normal);
      expect(insight.baselineMean, closeTo(70, 0.01));
      expect(insight.isUnusual, isTrue);
      expect(insight.zScore, greaterThan(2));
    });

    test('une valeur proche de la moyenne personnelle n\'est pas signalée', () {
      final insight = engine.analyze(_steadyHeartRate(latest: 71), now: _now).insights.single;
      expect(insight.isUnusual, isFalse);
      expect(insight.recentOutliers, isEmpty);
    });

    test('pas de référence personnelle avec trop peu de mesures', () {
      final few = [_m(MeasurementType.weight, 60, 4), _m(MeasurementType.weight, 61, 0)];
      final insight = engine.analyze(few, now: _now).insights.single;
      expect(insight.hasBaseline, isFalse);
      expect(insight.isUnusual, isFalse);
      expect(insight.trend, TrendDirection.unknown);
    });

    test('tendance à la hausse et projection à 30 jours', () {
      // +0,1 kg par jour : 60,0 il y a 20 jours → 62,0 aujourd'hui
      final weights = [for (int d = 20; d >= 0; d -= 2) _m(MeasurementType.weight, 62 - d * 0.1, d)];
      final insight = engine.analyze(weights, now: _now).insights.single;
      expect(insight.trend, TrendDirection.up);
      expect(insight.slopePerWeek, closeTo(0.7, 0.01));
      expect(insight.projected30d, closeTo(65, 0.1));
    });

    test('tendance stable quand les valeurs ne bougent presque pas', () {
      final insight = engine.analyze(_steadyHeartRate(latest: 70), now: _now).insights.single;
      expect(insight.trend, TrendDirection.stable);
    });

    test('régularité : mesures des 7 derniers jours et des 7 précédents', () {
      final list = [
        _m(MeasurementType.temperature, 36.8, 1),
        _m(MeasurementType.temperature, 36.7, 3),
        _m(MeasurementType.temperature, 36.9, 9),
      ];
      final insight = engine.analyze(list, now: _now).insights.single;
      expect(insight.last7Days, 2);
      expect(insight.previous7Days, 1);
      expect(insight.daysSinceLast, 1);
    });

    test('la glycémie à jeun n\'est pas comparée aux mesures après repas', () {
      final list = [
        for (int i = 8; i >= 1; i--)
          HealthMeasurement(
            id: 'g$i',
            type: MeasurementType.glycemia,
            value: i.isEven ? 90 : 150,
            glycemiaContext: i.isEven ? GlycemiaContext.fasting : GlycemiaContext.afterMeal,
            dateTime: _now.subtract(Duration(days: i)),
          ),
        HealthMeasurement(
          id: 'g0',
          type: MeasurementType.glycemia,
          value: 91,
          glycemiaContext: GlycemiaContext.fasting,
          dateTime: _now.subtract(const Duration(hours: 2)),
        ),
      ];
      final insight = engine.analyze(list, now: _now).insights.single;
      expect(insight.label, 'Glycémie (à jeun)');
      expect(insight.count, 5);
    });

    test('les données de démonstration signalent la fièvre et le pic de tension passés', () {
      final analysis = engine.analyze(HealthMeasurement.demoData(() => 'd${_id++}'));
      MetricInsight of(MeasurementType t) => analysis.insights.firstWhere((i) => i.type == t);
      expect(of(MeasurementType.temperature).recentOutliers.map((m) => m.value), contains(38.2));
      expect(of(MeasurementType.bloodPressure).recentOutliers.map((m) => m.value), contains(142));
      expect(engine.findings(analysis), contains('valeurs inhabituelles sur 30 jours'));
      expect(engine.offlineSummary(analysis), isNotEmpty);
    });

    test('référence de fréquence cardiaque pour la montre', () {
      final baseline = engine.heartRateBaseline(_steadyHeartRate(), now: _now);
      expect(baseline.mean, closeTo(70, 0.01));
      expect(baseline.stdDev, 4); // écart-type réel ≈ 2,1 → plancher de 4
      expect(baseline.zScore(95).abs(), greaterThan(3));
      // Sans historique : valeurs par défaut
      expect(engine.heartRateBaseline(const [], now: _now).mean, 72);
    });
  });

  group('Contrôle du texte du modèle', () {
    const guard = InsightTextGuard();

    test('accepte une description et retire la mise en forme', () {
      expect(guard.validate('**Votre poids** est stable sur les 30 derniers jours.'), startsWith('Votre poids est stable'));
    });

    test('rejette un chiffre absent des constats calculés', () {
      const source = 'dernière mesure : 64,0 kg ; moyenne habituelle : 65,8 kg ; tendance sur 30 jours';
      expect(guard.validate('Votre poids est de 64,0 kg, proche de votre moyenne de 65.8 kg.', source: source), isNotNull);
      expect(guard.validate('Votre poids est passé à 70 kg ce mois-ci, ce qui est stable.', source: source), isNull);
    });

    test('rejette un diagnostic, une prescription ou un texte vide', () {
      expect(guard.validate('Vous souffrez probablement d\'hypertension artérielle.'), isNull);
      expect(guard.validate('Prenez un comprimé de paracétamol matin et soir.'), isNull);
      expect(guard.validate('ok'), isNull);
    });
  });

  group('Service Hugging Face', () {
    test('envoie le jeton, le modèle et les messages, puis lit la réponse', () async {
      late http.Request sent;
      final service = HuggingFaceService(
        tokenOverride: 'hf_test',
        modelOverride: 'org/modele-test',
        client: MockClient((request) async {
          sent = request;
          return _hfAnswer('Bonjour, voici votre résumé.');
        }),
      );
      final answer = await service.chat(const [HfMessage('user', 'Résumé ?')]);
      expect(answer, 'Bonjour, voici votre résumé.');
      expect(sent.url.toString(), HuggingFaceService.endpoint);
      expect(sent.headers['Authorization'], 'Bearer hf_test');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['model'], 'org/modele-test');
      expect((body['messages'] as List).single['content'], 'Résumé ?');
      expect(service.modelName, 'modele-test');
    });

    test('utilise le Space du projet sans envoyer de jeton', () async {
      late http.Request sent;
      final service = HuggingFaceService(
        spaceUrlOverride: 'https://compte-space.hf.space/',
        tokenOverride: 'hf_test',
        client: MockClient((request) async {
          sent = request;
          return _hfAnswer('Réponse du Space.');
        }),
      );
      expect(service.isConfigured, isTrue);
      expect(await service.chat(const [HfMessage('user', 'x')]), 'Réponse du Space.');
      expect(sent.url.toString(), 'https://compte-space.hf.space/v1/chat/completions');
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(service.modelName, 'Qwen2.5-1.5B-Instruct');
    });

    test('signale un jeton refusé, un quota atteint et une réponse illisible', () async {
      HuggingFaceService withStatus(int code, [String body = '{}']) => HuggingFaceService(
        tokenOverride: 'hf_test',
        client: MockClient((_) async => http.Response(body, code)),
      );
      const msg = [HfMessage('user', 'x')];
      expect(() => withStatus(401).chat(msg), throwsA(isA<HuggingFaceException>()));
      expect(() => withStatus(429).chat(msg), throwsA(isA<HuggingFaceException>()));
      expect(() => withStatus(200).chat(msg), throwsA(isA<HuggingFaceException>()));
    });
  });

  group('Résumé de la semaine', () {
    ProviderContainer container(HuggingFaceService hf) {
      final c = ProviderContainer(
        overrides: [
          healthMeasurementLocalDataSourceProvider.overrideWithValue(
            _InMemoryDataSource(_steadyHeartRate(latest: 71)),
          ),
          huggingFaceServiceProvider.overrideWithValue(hf),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('rédigé par le modèle quand il répond correctement', () async {
      String? prompt;
      final c = container(
        HuggingFaceService(
          tokenOverride: 'hf_test',
          modelOverride: 'org/modele-test',
          client: MockClient((request) async {
            prompt = request.body;
            return _hfAnswer('Votre fréquence cardiaque reste proche de vos valeurs habituelles cette semaine.');
          }),
        ),
      );
      final report = await c.read(weeklyReportProvider.future);
      expect(report.fromAi, isTrue);
      expect(report.model, 'modele-test');
      // Le modèle reçoit les constats calculés, pas un texte libre
      expect(prompt, contains('moyenne habituelle de la personne'));
    });

    test('résumé local sans jeton, hors ligne ou si le modèle pose un diagnostic', () async {
      final noToken = await container(
        HuggingFaceService(client: MockClient((_) async => _hfAnswer('inutile'))),
      ).read(weeklyReportProvider.future);
      expect(noToken.fromAi, isFalse);
      expect(noToken.onDevice, isFalse);
      expect(noToken.text, contains('valeurs habituelles'));

      final offline = await container(
        HuggingFaceService(tokenOverride: 'hf_test', client: MockClient((_) async => throw Exception('réseau'))),
      ).read(weeklyReportProvider.future);
      expect(offline.fromAi, isFalse);
      expect(offline.fallbackReason, contains('impossible'));

      final unsafe = await container(
        HuggingFaceService(
          tokenOverride: 'hf_test',
          client: MockClient((_) async => _hfAnswer('Vous souffrez de tachycardie, consultez en urgence.')),
        ),
      ).read(weeklyReportProvider.future);
      expect(unsafe.fromAi, isFalse);
      expect(unsafe.fallbackReason, contains('contrôle de sécurité'));
    });
  });

  group('Montre connectée', () {
    test('vraie montre : lit le capteur Bluetooth, alerte, puis gère la déconnexion', () async {
      final sensor = _FakeSensor();
      final c = ProviderContainer(
        overrides: [
          healthMeasurementLocalDataSourceProvider.overrideWithValue(_InMemoryDataSource(_steadyHeartRate())),
          heartRateSensorProvider.overrideWithValue(sensor),
        ],
      );
      addTearDown(c.dispose);
      await c.read(healthMeasurementsProvider.future);
      final watch = c.read(connectedWatchProvider.notifier);

      // Aucun capteur choisi dans le navigateur : message d'erreur, pas de connexion
      sensor.fail = true;
      await watch.connectReal();
      expect(c.read(connectedWatchProvider).connected, isFalse);
      expect(c.read(connectedWatchProvider).error, isNotNull);

      sensor.fail = false;
      await watch.connectReal();
      addTearDown(watch.disconnect);
      var state = c.read(connectedWatchProvider);
      expect(state.connected, isTrue);
      expect(state.isReal, isTrue);
      expect(state.deviceName, 'Apple Watch');

      sensor.pending.addAll([71, 73, 118, 121]);
      watch.pollSensor();
      await Future<void>.delayed(Duration.zero);
      state = c.read(connectedWatchProvider);
      expect(state.readings, [71, 73, 118, 121]);
      expect(state.alert?.bpm, 121);
      expect(state.savedCount, 1);

      // Le bouton de démonstration n'agit pas sur une vraie montre
      watch.simulateSpike();
      sensor.connected = false;
      watch.pollSensor();
      state = c.read(connectedWatchProvider);
      expect(state.connected, isFalse);
      expect(state.error, contains('déconnectée'));
    });

    test('détecte un pic, alerte une seule fois et enregistre la mesure', () async {
      final source = _InMemoryDataSource(_steadyHeartRate());
      final c = ProviderContainer(overrides: [healthMeasurementLocalDataSourceProvider.overrideWithValue(source)]);
      addTearDown(c.dispose);
      await c.read(healthMeasurementsProvider.future);
      final before = source.rows.length;

      final watch = c.read(connectedWatchProvider.notifier);
      watch.connect();
      addTearDown(watch.disconnect);
      expect(c.read(connectedWatchProvider).baseline!.mean, closeTo(70, 0.01));

      watch.receive(72);
      watch.receive(110); // une seule valeur haute : pas encore d'alerte
      expect(c.read(connectedWatchProvider).alert, isNull);
      watch.receive(112);
      watch.receive(115);
      await Future<void>.delayed(Duration.zero);

      final state = c.read(connectedWatchProvider);
      expect(state.alert?.bpm, 112);
      expect(state.savedCount, 1);
      expect(source.rows.length, before + 1);
      expect(source.rows.values.any((m) => m.note.contains('valeur inhabituelle')), isTrue);

      watch.dismissAlert();
      expect(c.read(connectedWatchProvider).alert, isNull);
    });
  });
}
