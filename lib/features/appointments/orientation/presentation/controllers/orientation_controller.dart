import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahacare/features/appointments/presentation/controllers/appointments_controller.dart';
import 'package:sahacare/features/appointments/orientation/data/constants/orientation_constants.dart';
import 'package:sahacare/features/appointments/orientation/data/datasources/gemini_service.dart';
import 'package:sahacare/features/appointments/orientation/data/datasources/orientation_local_datasource.dart';
import 'package:sahacare/features/appointments/orientation/domain/emergency_detector.dart';
import 'package:sahacare/features/appointments/orientation/domain/entities/orientation_recommendation.dart';
import 'package:sahacare/features/appointments/orientation/domain/entities/orientation_result.dart';
import 'package:sahacare/features/appointments/orientation/domain/repositories/orientation_repository.dart';
import 'package:sahacare/features/appointments/orientation/data/repositories/orientation_repository_impl.dart';

// ============================================================================
// Providers
// ============================================================================

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final service = GeminiService();
  ref.onDispose(() => service.close());
  return service;
});

final orientationLocalDataSourceProvider =
    Provider<OrientationLocalDataSource>((ref) {
  return OrientationLocalDataSourceImpl();
});

final orientationRepositoryProvider = Provider<OrientationRepository>((ref) {
  return OrientationRepositoryImpl(
    geminiService: ref.watch(geminiServiceProvider),
    localDataSource: ref.watch(orientationLocalDataSourceProvider),
    doctorLocalDataSource: ref.watch(doctorLocalDataSourceProvider),
  );
});

// ============================================================================
// État Riverpod
// ============================================================================

enum OrientationStep {
  initial,
  consentRequired,
  loading,
  emergencyAlert,
  result,
  needsMoreInfo,
  error,
}

class OrientationState {
  final OrientationStep step;
  final String inputText;
  final String accumulatedText;
  final int clarificationTurns;
  final EmergencyDetectionResult? emergencyResult;
  final OrientationResult? orientationResult;
  final List<OrientationRecommendation> recommendations;
  final String? clarificationQuestion;
  final String? errorMessage;
  final bool isKeyMissing;
  final bool isQuotaExceeded;
  final bool isNetworkError;
  final DateTime? lastRequestTime;

  const OrientationState({
    this.step = OrientationStep.initial,
    this.inputText = '',
    this.accumulatedText = '',
    this.clarificationTurns = 0,
    this.emergencyResult,
    this.orientationResult,
    this.recommendations = const [],
    this.clarificationQuestion,
    this.errorMessage,
    this.isKeyMissing = false,
    this.isQuotaExceeded = false,
    this.isNetworkError = false,
    this.lastRequestTime,
  });

  bool get isLoading => step == OrientationStep.loading;
  bool get isEmergency =>
      step == OrientationStep.emergencyAlert ||
      (orientationResult?.urgency == 'emergency');
  bool get hasResult =>
      step == OrientationStep.result && orientationResult != null;
  bool get isDegradedMode => orientationResult?.isDegradedMode ?? false;

  OrientationState copyWith({
    OrientationStep? step,
    String? inputText,
    String? accumulatedText,
    int? clarificationTurns,
    EmergencyDetectionResult? Function()? emergencyResult,
    OrientationResult? Function()? orientationResult,
    List<OrientationRecommendation>? recommendations,
    String? Function()? clarificationQuestion,
    String? Function()? errorMessage,
    bool? isKeyMissing,
    bool? isQuotaExceeded,
    bool? isNetworkError,
    DateTime? lastRequestTime,
  }) {
    return OrientationState(
      step: step ?? this.step,
      inputText: inputText ?? this.inputText,
      accumulatedText: accumulatedText ?? this.accumulatedText,
      clarificationTurns: clarificationTurns ?? this.clarificationTurns,
      emergencyResult:
          emergencyResult != null ? emergencyResult() : this.emergencyResult,
      orientationResult: orientationResult != null
          ? orientationResult()
          : this.orientationResult,
      recommendations: recommendations ?? this.recommendations,
      clarificationQuestion: clarificationQuestion != null
          ? clarificationQuestion()
          : this.clarificationQuestion,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      isKeyMissing: isKeyMissing ?? this.isKeyMissing,
      isQuotaExceeded: isQuotaExceeded ?? this.isQuotaExceeded,
      isNetworkError: isNetworkError ?? this.isNetworkError,
      lastRequestTime: lastRequestTime ?? this.lastRequestTime,
    );
  }
}

// ============================================================================
// Notifier
// ============================================================================

final orientationControllerProvider =
    NotifierProvider<OrientationNotifier, OrientationState>(
  OrientationNotifier.new,
);

class OrientationNotifier extends Notifier<OrientationState> {
  @override
  OrientationState build() {
    // Vérification initiale du consentement
    Future.microtask(() => checkConsent());
    return const OrientationState();
  }

  OrientationRepository get _repository =>
      ref.read(orientationRepositoryProvider);

  /// Vérifie si l'utilisateur a consenti à l'envoi de la description à l'IA
  Future<void> checkConsent() async {
    final consented = await _repository.hasUserConsented();
    if (!consented && state.step == OrientationStep.initial) {
      state = state.copyWith(step: OrientationStep.consentRequired);
    }
  }

  /// Accepte le consentement
  Future<void> giveConsent() async {
    await _repository.setUserConsented(true);
    state = state.copyWith(step: OrientationStep.initial);
  }

  /// Met à jour le texte saisi
  void setInputText(String text) {
    state = state.copyWith(inputText: text);
  }

  /// Lance l'analyse des symptômes
  Future<void> analyzeSymptoms(
    String text, {
    bool bypassEmergency = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.length < OrientationConstants.minSymptomsLength) {
      state = state.copyWith(
        step: OrientationStep.error,
        errorMessage: () =>
            "Veuillez décrire vos symptômes plus en détail (au moins ${OrientationConstants.minSymptomsLength} caractères).",
      );
      return;
    }

    // Protection anti-spam
    final now = DateTime.now();
    if (state.lastRequestTime != null &&
        now.difference(state.lastRequestTime!).inSeconds <
            OrientationConstants.antiSpamDelaySeconds) {
      return;
    }

    // 1. Détection locale d'urgence (instantanée, sans LLM)
    if (!bypassEmergency) {
      final emergency = EmergencyDetector.analyze(trimmed);
      if (emergency.isEmergency) {
        state = state.copyWith(
          step: OrientationStep.emergencyAlert,
          emergencyResult: () => emergency,
          inputText: trimmed,
          accumulatedText: trimmed,
        );
        return;
      }
    }

    // 2. Vérification du consentement
    final consented = await _repository.hasUserConsented();
    if (!consented) {
      state = state.copyWith(
        step: OrientationStep.consentRequired,
        inputText: trimmed,
        accumulatedText: trimmed,
      );
      return;
    }

    // 3. Appel au service d'analyse
    state = state.copyWith(
      step: OrientationStep.loading,
      inputText: trimmed,
      accumulatedText: trimmed,
      clarificationTurns: 0,
      errorMessage: () => null,
      isKeyMissing: false,
      isQuotaExceeded: false,
      isNetworkError: false,
      lastRequestTime: now,
    );

    await _performOrientation(trimmed);
  }

  /// Répond à une question de clarification (max 2 tours)
  Future<void> answerClarification(String answer) async {
    final trimmedAnswer = answer.trim();
    if (trimmedAnswer.isEmpty) return;

    final turns = state.clarificationTurns + 1;
    final combined =
        '${state.accumulatedText}. Précision de l\'utilisateur : $trimmedAnswer';

    // Si on a atteint 2 tours de clarification, on oriente vers Médecine Générale
    if (turns >= 2) {
      state = state.copyWith(
        step: OrientationStep.loading,
        accumulatedText: combined,
        clarificationTurns: turns,
      );
      await _orientToGeneralPractice(combined);
      return;
    }

    state = state.copyWith(
      step: OrientationStep.loading,
      accumulatedText: combined,
      clarificationTurns: turns,
    );

    await _performOrientation(combined);
  }

  Future<void> _performOrientation(String textToAnalyze) async {
    try {
      final output = await _repository.orientSymptoms(textToAnalyze);

      // Si le LLM a classé en urgence, afficher l'alerte
      if (output.result.urgency == 'emergency') {
        state = state.copyWith(
          step: OrientationStep.emergencyAlert,
          emergencyResult: () => const EmergencyDetectionResult(
            isEmergency: true,
            isSuicidal: false,
            matchedTriggers: ['Indiqué par le service médical'],
          ),
          orientationResult: () => output.result,
          recommendations: output.recommendations,
        );
        return;
      }

      // Si le LLM a besoin de plus d'informations
      if (output.result.needsMoreInfo &&
          output.result.clarificationQuestion != null &&
          state.clarificationTurns < 2) {
        state = state.copyWith(
          step: OrientationStep.needsMoreInfo,
          clarificationQuestion: () => output.result.clarificationQuestion,
          orientationResult: () => output.result,
          recommendations: output.recommendations,
        );
        return;
      }

      // Résultat standard validé
      state = state.copyWith(
        step: OrientationStep.result,
        orientationResult: () => output.result,
        recommendations: output.recommendations,
      );
    } on GeminiKeyMissingException {
      state = state.copyWith(
        step: OrientationStep.error,
        isKeyMissing: true,
        errorMessage: () =>
            "Service d'orientation non configuré. Aucune clé API Gemini n'a été trouvée.",
      );
    } on GeminiAuthException {
      state = state.copyWith(
        step: OrientationStep.error,
        isKeyMissing: true,
        errorMessage: () =>
            "Clé API Gemini invalide ou non autorisée. Veuillez vérifier votre fichier .env.",
      );
    } on GeminiQuotaException {
      state = state.copyWith(
        step: OrientationStep.error,
        isQuotaExceeded: true,
        errorMessage: () =>
            "Limite de requêtes atteinte sur l'API Gemini. Vous pouvez utiliser le mode dégradé hors-ligne.",
      );
    } on GeminiNetworkException {
      state = state.copyWith(
        step: OrientationStep.error,
        isNetworkError: true,
        errorMessage: () =>
            "Impossible de joindre le serveur d'orientation. Vous pouvez basculer sur l'orientation locale.",
      );
    } catch (e) {
      state = state.copyWith(
        step: OrientationStep.error,
        errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Passe manuellement ou après erreur en mode dégradé hors-ligne
  Future<void> useDegradedMode([String? fallbackText]) async {
    final text = fallbackText ??
        (state.accumulatedText.isNotEmpty
            ? state.accumulatedText
            : state.inputText);
    if (text.trim().isEmpty) return;

    state = state.copyWith(
      step: OrientationStep.loading,
      errorMessage: () => null,
    );

    try {
      final output = await _repository.orientSymptomsOffline(text);
      state = state.copyWith(
        step: OrientationStep.result,
        orientationResult: () => output.result,
        recommendations: output.recommendations,
      );
    } catch (e) {
      state = state.copyWith(
        step: OrientationStep.error,
        errorMessage: () =>
            "Erreur lors de l'orientation locale : ${e.toString()}",
      );
    }
  }

  Future<void> _orientToGeneralPractice(String text) async {
    try {
      final allDoctors =
          await ref.read(doctorLocalDataSourceProvider).getDoctors();
      final generalDocs = allDoctors.where((d) {
        return d.specialty.toLowerCase().contains('générale') ||
            d.specialty.toLowerCase().contains('generale');
      }).toList();

      final result = OrientationResult(
        recommendedSpecialties: const [
          RecommendedSpecialty(
            name: 'Médecine Générale',
            reason:
                'Vos symptômes nécessitent un examen clinique général pour cibler au mieux le bon spécialiste.',
            confidence: 'high',
          ),
        ],
        urgency: 'routine',
        needsMoreInfo: false,
        advice:
            'Consultez votre médecin traitant ou un médecin généraliste pour une première évaluation.',
      );

      final recs = [
        OrientationRecommendation(
          specialty: result.recommendedSpecialties.first,
          notebookDoctors: generalDocs,
        ),
      ];

      state = state.copyWith(
        step: OrientationStep.result,
        orientationResult: () => result,
        recommendations: recs,
      );
    } catch (e) {
      state = state.copyWith(
        step: OrientationStep.error,
        errorMessage: () => e.toString(),
      );
    }
  }

  /// Réinitialise l'état pour une nouvelle consultation
  void reset() {
    state = const OrientationState(step: OrientationStep.initial);
  }
}
