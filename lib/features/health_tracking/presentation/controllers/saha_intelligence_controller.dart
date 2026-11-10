import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/heart_rate_sensor.dart';
import '../../data/datasources/hugging_face_service.dart';
import '../../domain/entities/health_insight.dart';
import '../../domain/entities/health_measurement.dart';
import '../../domain/services/health_analysis_engine.dart';
import '../../domain/services/insight_text_guard.dart';
import 'health_tracking_controller.dart';

// ============================================================================
// Moteur d'analyse (local) et modèle de langage (Hugging Face)
// ============================================================================

final healthAnalysisEngineProvider = Provider<HealthAnalysisEngine>((ref) => const HealthAnalysisEngine());

final insightTextGuardProvider = Provider<InsightTextGuard>((ref) => const InsightTextGuard());

final huggingFaceServiceProvider = Provider<HuggingFaceService>((ref) {
  final service = HuggingFaceService();
  ref.onDispose(service.close);
  return service;
});

/// Analyse recalculée à chaque changement des mesures (null pendant le chargement)
final healthAnalysisProvider = Provider<HealthAnalysis?>((ref) {
  final all = ref.watch(healthMeasurementsProvider).value;
  if (all == null) return null;
  return ref.watch(healthAnalysisEngineProvider).analyze(all);
});

const String _systemPrompt =
    'Tu es l\'assistant de l\'application de suivi de santé SahaCare. '
    'Tu reçois des constats déjà calculés par l\'application à partir des mesures de l\'utilisateur. '
    'Tu réponds en français, en vouvoyant, avec des phrases simples et bienveillantes. '
    'Règles strictes : utilise uniquement les chiffres fournis, n\'en invente aucun ; '
    'ne pose aucun diagnostic et ne nomme aucune maladie ; ne recommande aucun médicament ni traitement ; '
    'si une valeur est inhabituelle, propose simplement d\'en parler à un professionnel de santé. '
    'Pas de titres, pas de listes, pas de mise en forme.';

// ============================================================================
// Résumé de la semaine
// ============================================================================

class InsightReport {
  final String text;

  /// true : rédigé par le modèle Hugging Face ; false : résumé calculé localement
  final bool fromAi;
  final String? model;

  /// Raison de l'utilisation du résumé local (hors ligne, jeton absent, texte rejeté…)
  final String? fallbackReason;

  /// true : le modèle a tourné dans le navigateur, rien n'a été envoyé sur Internet
  final bool onDevice;

  const InsightReport({
    required this.text,
    required this.fromAi,
    this.model,
    this.fallbackReason,
    this.onDevice = false,
  });
}

/// Avancement du modèle exécuté dans le navigateur (null s'il n'y a rien à afficher)
final llmStatusProvider = StreamProvider.autoDispose<String?>((ref) async* {
  final hf = ref.watch(huggingFaceServiceProvider);
  if (!hf.usesBrowser) {
    yield null;
    return;
  }
  while (true) {
    final state = hf.browserLlm.state;
    yield switch (state.status) {
      'loading' => 'Téléchargement du modèle Hugging Face dans le navigateur… ${state.progress} %',
      'generating' => 'Le modèle ${hf.modelName} rédige…',
      _ => null,
    };
    await Future<void>.delayed(const Duration(seconds: 1));
  }
});

/// Garde le dernier résumé généré : le modèle n'est rappelé que si les constats ont changé
class _ReportCache {
  String? findings;
  InsightReport? report;

  /// Vrai quand l'utilisateur a demandé un nouveau résumé
  bool force = false;
}

final _reportCacheProvider = Provider<_ReportCache>((ref) => _ReportCache());

class WeeklyReportNotifier extends AsyncNotifier<InsightReport> {
  @override
  Future<InsightReport> build() async {
    final engine = ref.read(healthAnalysisEngineProvider);
    final measurements = await ref.read(healthMeasurementsProvider.future);
    final analysis = engine.analyze(measurements);
    final findings = engine.findings(analysis);

    final cache = ref.read(_reportCacheProvider);
    final force = cache.force;
    cache.force = false;
    if (!force && cache.findings == findings && cache.report != null) return cache.report!;

    final report = await _generate(engine, analysis, findings);
    if (report.fromAi) {
      cache
        ..findings = findings
        ..report = report;
    }
    return report;
  }

  Future<InsightReport> _generate(HealthAnalysisEngine engine, HealthAnalysis analysis, String findings) async {
    InsightReport local(String reason) =>
        InsightReport(text: engine.offlineSummary(analysis), fromAi: false, fallbackReason: reason);

    if (analysis.isEmpty) return local('Aucune mesure à analyser.');
    final hf = ref.read(huggingFaceServiceProvider);
    if (!hf.isConfigured) return local('Modèle Hugging Face non disponible sur cet appareil.');
    final summary = engine.offlineSummary(analysis);
    try {
      final raw = await hf.chat([
        const HfMessage('system', _systemPrompt),
        // Un petit modèle embarqué reformule mieux qu'il ne raisonne : on lui confie
        // le résumé déjà calculé. Un grand modèle reçoit les constats détaillés.
        if (hf.usesBrowser)
          HfMessage(
            'user',
            'Réécrivez ce résumé de santé avec des phrases simples et bienveillantes, en vous adressant à la '
                'personne avec « vous ». Gardez exactement les mêmes chiffres et n\'ajoutez aucune information.\n\n'
                '$summary',
          )
        else
          HfMessage(
            'user',
            'Voici les constats de la semaine :\n\n$findings\n\n'
                'Rédige un résumé de 4 à 6 phrases : ce qui est habituel, ce qui change, et la régularité du suivi.',
          ),
      ], maxTokens: 260);
      // Tout chiffre du texte doit provenir des constats calculés
      final text = ref.read(insightTextGuardProvider).validate(raw, source: '$findings\n$summary');
      if (text == null) return local('Réponse du modèle écartée par le contrôle de sécurité.');
      return InsightReport(text: text, fromAi: true, model: hf.modelName, onDevice: hf.usesBrowser);
    } on HuggingFaceException catch (e) {
      return local(e.message);
    }
  }

  /// Redemande un résumé au modèle, même si les constats n'ont pas changé
  void regenerate() {
    ref.read(_reportCacheProvider).force = true;
    ref.invalidateSelf();
  }
}

final weeklyReportProvider = AsyncNotifierProvider<WeeklyReportNotifier, InsightReport>(WeeklyReportNotifier.new);

// ============================================================================
// Questions à l'assistant
// ============================================================================

class ChatEntry {
  final String text;
  final bool fromUser;
  final bool isError;

  const ChatEntry(this.text, {required this.fromUser, this.isError = false});
}

class AssistantChatState {
  final List<ChatEntry> entries;
  final bool sending;

  const AssistantChatState({this.entries = const [], this.sending = false});
}

class AssistantChatNotifier extends Notifier<AssistantChatState> {
  @override
  AssistantChatState build() => const AssistantChatState();

  Future<void> ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || state.sending) return;
    final history = state.entries;
    state = AssistantChatState(entries: [...history, ChatEntry(q, fromUser: true)], sending: true);

    final answer = await _answer(q, history);
    if (!ref.mounted) return;
    state = AssistantChatState(entries: [...state.entries, answer]);
  }

  /// Indicateurs mentionnés dans une question (vide si aucun n'est reconnu)
  static Set<MeasurementType> _typesIn(String question) {
    final q = question.toLowerCase();
    bool has(List<String> words) => words.any(q.contains);
    return {
      if (has(['poids', 'kilo', 'kg'])) MeasurementType.weight,
      if (has(['températ', 'temperat', 'fièvre', 'fievre'])) MeasurementType.temperature,
      if (has(['tension', 'pression'])) MeasurementType.bloodPressure,
      if (has(['glyc', 'sucre'])) MeasurementType.glycemia,
      if (has(['cardia', 'cœur', 'coeur', 'pouls', 'bpm'])) MeasurementType.heartRate,
    };
  }

  Future<ChatEntry> _answer(String question, List<ChatEntry> history) async {
    final hf = ref.read(huggingFaceServiceProvider);
    if (!hf.isConfigured) {
      return const ChatEntry('L\'assistant n\'est pas disponible sur cet appareil.', fromUser: false, isError: true);
    }
    final engine = ref.read(healthAnalysisEngineProvider);
    final measurements = ref.read(healthMeasurementsProvider).value ?? const <HealthMeasurement>[];
    var analysis = engine.analyze(measurements);
    // Seuls les indicateurs cités dans la question sont transmis : réponse plus rapide et plus fidèle
    final asked = _typesIn(question);
    if (asked.isNotEmpty) {
      analysis = HealthAnalysis(
        generatedAt: analysis.generatedAt,
        insights: analysis.insights.where((i) => asked.contains(i.type)).toList(),
      );
    }
    final findings = engine.findings(analysis);
    try {
      final raw = await hf.chat([
        HfMessage(
          'system',
          '$_systemPrompt Réponds en 2 à 4 phrases, uniquement à partir des constats ci-dessous. '
              'Si la question sort de ces données, dis que tu ne peux répondre que sur les mesures enregistrées.\n\n'
              'Constats :\n$findings',
        ),
        // Les derniers échanges donnent le contexte de la conversation
        for (final e in history.where((e) => !e.isError).toList().reversed.take(6).toList().reversed)
          HfMessage(e.fromUser ? 'user' : 'assistant', e.text),
        HfMessage('user', question),
      ], maxTokens: 160);
      final text = ref.read(insightTextGuardProvider).validate(raw, source: '$findings\n$question');
      if (text == null) {
        return const ChatEntry(
          'Je ne peux pas répondre à cette question. Pour un avis médical, adressez-vous à un professionnel de santé.',
          fromUser: false,
        );
      }
      return ChatEntry(text, fromUser: false);
    } on HuggingFaceException catch (e) {
      return ChatEntry(e.message, fromUser: false, isError: true);
    }
  }

  void clear() => state = const AssistantChatState();
}

final assistantChatProvider = NotifierProvider<AssistantChatNotifier, AssistantChatState>(AssistantChatNotifier.new);

// ============================================================================
// Montre connectée (simulation d'un flux de fréquence cardiaque)
// ============================================================================

class WatchAlert {
  final double bpm;
  final DateTime at;
  final LiveBaseline baseline;

  const WatchAlert({required this.bpm, required this.at, required this.baseline});
}

/// Origine des valeurs : capteur simulé ou vraie montre lue en Bluetooth
enum WatchSource { simulated, real }

final heartRateSensorProvider = Provider<HeartRateSensor>((ref) => createHeartRateSensor());

class WatchState {
  final bool connected;
  final WatchSource source;

  /// Nom du capteur Bluetooth connecté (vraie montre)
  final String? deviceName;

  /// Recherche d'un capteur Bluetooth en cours
  final bool connecting;

  /// Dernier problème de connexion à afficher
  final String? error;

  /// Dernières valeurs reçues (bpm), de la plus ancienne à la plus récente
  final List<double> readings;
  final LiveBaseline? baseline;
  final WatchAlert? alert;

  /// Nombre de mesures de la session enregistrées dans l'historique
  final int savedCount;

  const WatchState({
    this.connected = false,
    this.source = WatchSource.simulated,
    this.deviceName,
    this.connecting = false,
    this.error,
    this.readings = const [],
    this.baseline,
    this.alert,
    this.savedCount = 0,
  });

  double? get current => readings.isEmpty ? null : readings.last;

  bool get isReal => source == WatchSource.real;

  WatchState copyWith({
    bool? connected,
    WatchSource? source,
    String? Function()? deviceName,
    bool? connecting,
    String? Function()? error,
    List<double>? readings,
    LiveBaseline? Function()? baseline,
    WatchAlert? Function()? alert,
    int? savedCount,
  }) {
    return WatchState(
      connected: connected ?? this.connected,
      source: source ?? this.source,
      deviceName: deviceName != null ? deviceName() : this.deviceName,
      connecting: connecting ?? this.connecting,
      error: error != null ? error() : this.error,
      readings: readings ?? this.readings,
      baseline: baseline != null ? baseline() : this.baseline,
      alert: alert != null ? alert() : this.alert,
      savedCount: savedCount ?? this.savedCount,
    );
  }
}

class ConnectedWatchNotifier extends Notifier<WatchState> {
  static const Duration tick = Duration(seconds: 2);
  static const int maxReadings = 40;

  /// Une mesure normale est enregistrée dans l'historique toutes les [saveEvery] réceptions
  static const int saveEvery = 15;

  /// Écart (en écarts-types) à partir duquel une valeur en direct est inhabituelle
  static const double alertZ = 3;
  static const int spikeTicks = 8;

  final math.Random _random = math.Random();
  Timer? _timer;
  int _ticks = 0;
  int _spikeLeft = 0;
  int _unusualStreak = 0;
  bool _episodeSaved = false;

  @override
  WatchState build() {
    ref.onDispose(() => _timer?.cancel());
    final sensor = ref.read(heartRateSensorProvider);
    ref.onDispose(sensor.disconnect);
    return const WatchState();
  }

  LiveBaseline _startSession() {
    final all = ref.read(healthMeasurementsProvider).value ?? const <HealthMeasurement>[];
    _ticks = 0;
    _spikeLeft = 0;
    _unusualStreak = 0;
    _episodeSaved = false;
    return ref.read(healthAnalysisEngineProvider).heartRateBaseline(all);
  }

  /// Choix de l'origine des valeurs (uniquement quand la montre est déconnectée)
  void selectSource(WatchSource source) {
    if (state.connected || state.connecting) return;
    state = state.copyWith(source: source, error: () => null);
  }

  /// Connecte la montre simulée
  void connect() {
    if (state.connected) return;
    final baseline = _startSession();
    state = WatchState(connected: true, baseline: baseline, readings: [baseline.mean.roundToDouble()]);
    _timer = Timer.periodic(tick, (_) => receive(_nextValue()));
  }

  /// Connecte une vraie montre : capteur de fréquence cardiaque Bluetooth choisi dans le navigateur
  Future<void> connectReal() async {
    if (state.connected || state.connecting) return;
    final sensor = ref.read(heartRateSensorProvider);
    if (!sensor.isSupported) {
      state = state.copyWith(
        source: WatchSource.real,
        error: () => 'Bluetooth indisponible dans ce navigateur. Utilisez Chrome sur un ordinateur équipé du Bluetooth.',
      );
      return;
    }
    state = state.copyWith(source: WatchSource.real, connecting: true, error: () => null);
    try {
      final name = await sensor.connect();
      if (!ref.mounted) return;
      final baseline = _startSession();
      state = WatchState(connected: true, source: WatchSource.real, deviceName: name, baseline: baseline);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => pollSensor());
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        connecting: false,
        error: () => 'Aucun capteur connecté. Vérifiez que la diffusion est lancée sur la montre, puis réessayez.',
      );
    }
  }

  /// Récupère les valeurs envoyées par la vraie montre depuis la dernière lecture
  void pollSensor() {
    if (!state.connected || !state.isReal) return;
    final sensor = ref.read(heartRateSensorProvider);
    for (final bpm in sensor.drain()) {
      receive(bpm);
    }
    if (!sensor.isConnected) {
      disconnect();
      state = state.copyWith(error: () => 'La montre s\'est déconnectée.');
    }
  }

  void disconnect() {
    _timer?.cancel();
    _timer = null;
    if (state.isReal) ref.read(heartRateSensorProvider).disconnect();
    state = state.copyWith(connected: false, connecting: false);
  }

  /// Démonstration : la montre simulée envoie des valeurs anormalement élevées pendant quelques secondes
  void simulateSpike() {
    if (state.connected && !state.isReal) _spikeLeft = spikeTicks;
  }

  void dismissAlert() => state = state.copyWith(alert: () => null);

  /// Valeur suivante du capteur simulé : marche aléatoire ramenée vers la moyenne personnelle
  double _nextValue() {
    final baseline = state.baseline!;
    final previous = state.current ?? baseline.mean;
    final target = _spikeLeft > 0 ? baseline.mean + 5 * baseline.stdDev + 12 : baseline.mean;
    if (_spikeLeft > 0) _spikeLeft--;
    final noise = (_random.nextDouble() - 0.5) * baseline.stdDev * 0.8;
    return (previous + (target - previous) * 0.45 + noise).roundToDouble();
  }

  /// Traite une valeur reçue de la montre : affichage, détection, enregistrement
  void receive(double bpm) {
    final baseline = state.baseline;
    if (!state.connected || baseline == null) return;
    _ticks++;
    final readings = [...state.readings, bpm];
    if (readings.length > maxReadings) readings.removeAt(0);
    state = state.copyWith(readings: readings);

    final unusual = baseline.zScore(bpm).abs() >= alertZ;
    _unusualStreak = unusual ? _unusualStreak + 1 : 0;
    if (!unusual) _episodeSaved = false;

    // Deux valeurs inhabituelles de suite : on alerte et on garde une trace dans l'historique
    if (_unusualStreak >= 2 && !_episodeSaved) {
      _episodeSaved = true;
      state = state.copyWith(alert: () => WatchAlert(bpm: bpm, at: DateTime.now(), baseline: baseline));
      _save(bpm, 'Montre connectée · valeur inhabituelle détectée');
    } else if (!unusual && _ticks % (state.isReal ? saveEvery * 2 : saveEvery) == 0) {
      _save(bpm, 'Montre connectée');
    }
  }

  Future<void> _save(double bpm, String note) async {
    try {
      await ref
          .read(healthMeasurementsProvider.notifier)
          .add(HealthMeasurement(id: '', type: MeasurementType.heartRate, value: bpm, dateTime: DateTime.now(), note: note));
      if (ref.mounted) state = state.copyWith(savedCount: state.savedCount + 1);
    } catch (_) {
      // L'affichage en direct continue même si l'enregistrement échoue
    }
  }
}

final connectedWatchProvider = NotifierProvider<ConnectedWatchNotifier, WatchState>(ConnectedWatchNotifier.new);
