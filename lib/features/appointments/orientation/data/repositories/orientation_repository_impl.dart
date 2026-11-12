import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:sahacare/features/appointments/data/datasources/doctor_local_datasource.dart';
import 'package:sahacare/features/appointments/domain/entities/doctor.dart';
import 'package:sahacare/features/appointments/orientation/data/constants/orientation_constants.dart';
import 'package:sahacare/features/appointments/orientation/data/datasources/gemini_service.dart';
import 'package:sahacare/features/appointments/orientation/data/datasources/orientation_local_datasource.dart';
import 'package:sahacare/features/appointments/orientation/data/models/orientation_history_entry.dart';
import 'package:sahacare/features/appointments/orientation/domain/entities/orientation_recommendation.dart';
import 'package:sahacare/features/appointments/orientation/domain/entities/orientation_result.dart';
import 'package:sahacare/features/appointments/orientation/domain/repositories/orientation_repository.dart';

class OrientationRepositoryImpl implements OrientationRepository {
  final GeminiService geminiService;
  final OrientationLocalDataSource localDataSource;
  final DoctorLocalDataSource doctorLocalDataSource;
  final SharedPreferences? sharedPreferences;

  OrientationRepositoryImpl({
    required this.geminiService,
    required this.localDataSource,
    required this.doctorLocalDataSource,
    this.sharedPreferences,
  });

  @override
  Future<List<String>> getAllowedSpecialties() async {
    return await localDataSource.getAllowedSpecialties();
  }

  @override
  Future<({OrientationResult result, List<OrientationRecommendation> recommendations})>
      orientSymptoms(String symptomsText) async {
    _validateInput(symptomsText);

    final allowedSpecialties = await getAllowedSpecialties();

    final rawJson = await geminiService.orientSymptoms(
      symptomsText: symptomsText.trim(),
      allowedSpecialties: allowedSpecialties,
    );

    final parsedResult = OrientationResult.fromJson(rawJson);

    // Validation et filtrage strict des spécialités par rapport à la base
    final validatedSpecialties = <RecommendedSpecialty>[];
    for (final spec in parsedResult.recommendedSpecialties) {
      final canonical = _findCanonicalMatch(spec.name, allowedSpecialties);
      if (canonical != null) {
        validatedSpecialties.add(RecommendedSpecialty(
          name: canonical,
          reason: spec.reason,
          confidence: spec.confidence,
        ));
      }
    }

    OrientationResult finalResult;
    if (validatedSpecialties.isEmpty && !parsedResult.needsMoreInfo) {
      finalResult = parsedResult.copyWith(
        recommendedSpecialties: const [],
        advice:
            "Je n'ai pas pu déterminer une spécialité, essayez de préciser vos symptômes ou consultez un généraliste.",
      );
    } else {
      finalResult = parsedResult.copyWith(
        recommendedSpecialties: validatedSpecialties,
      );
    }

    // Association aux médecins du carnet
    final allDoctors = await doctorLocalDataSource.getDoctors();
    final recommendations = _matchDoctors(finalResult.recommendedSpecialties, allDoctors);

    // Sauvegarde automatique en historique (si pas en attente d'info)
    if (!finalResult.needsMoreInfo && finalResult.recommendedSpecialties.isNotEmpty) {
      await saveHistory(symptomsText: symptomsText, result: finalResult);
    }

    return (result: finalResult, recommendations: recommendations);
  }

  @override
  Future<({OrientationResult result, List<OrientationRecommendation> recommendations})>
      orientSymptomsOffline(String symptomsText) async {
    _validateInput(symptomsText);

    final allowedSpecialties = await getAllowedSpecialties();
    final normalized = _normalizeText(symptomsText);

    final scores = <String, int>{};

    for (final entry in OrientationConstants.keywordToSpecialtyMapping.entries) {
      final spec = entry.key;
      final keywords = entry.value;
      int matchCount = 0;
      for (final kw in keywords) {
        if (normalized.contains(_normalizeText(kw))) {
          matchCount++;
        }
      }
      if (matchCount > 0) {
        scores[spec] = matchCount;
      }
    }

    final recommended = <RecommendedSpecialty>[];

    if (scores.isEmpty) {
      // Orientation par défaut vers Médecine Générale
      recommended.add(const RecommendedSpecialty(
        name: 'Médecine Générale',
        reason:
            "En l'absence de signe spécifique identifiable hors-ligne, un médecin généraliste saura vous orienter.",
        confidence: 'medium',
      ));
    } else {
      final sortedEntries = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final e in sortedEntries.take(2)) {
        final canonical = _findCanonicalMatch(e.key, allowedSpecialties);
        if (canonical != null) {
          recommended.add(RecommendedSpecialty(
            name: canonical,
            reason:
                "Correspondance détectée localement avec vos symptômes décrits.",
            confidence: e.value >= 2 ? 'high' : 'medium',
          ));
        }
      }
    }

    final result = OrientationResult(
      recommendedSpecialties: recommended,
      urgency: 'routine',
      needsMoreInfo: false,
      advice:
          "Mode dégradé hors-ligne : suggestion établie par analyse locale de mots-clés.",
      isDegradedMode: true,
    );

    final allDoctors = await doctorLocalDataSource.getDoctors();
    final recommendations = _matchDoctors(result.recommendedSpecialties, allDoctors);

    return (result: result, recommendations: recommendations);
  }

  void _validateInput(String text) {
    final trimmed = text.trim();
    if (trimmed.length < OrientationConstants.minSymptomsLength) {
      throw ArgumentError(
        "Veuillez décrire vos symptômes plus en détail (au moins ${OrientationConstants.minSymptomsLength} caractères).",
      );
    }
    if (trimmed.length > OrientationConstants.maxSymptomsLength) {
      throw ArgumentError(
        "Votre description ne doit pas dépasser ${OrientationConstants.maxSymptomsLength} caractères.",
      );
    }
  }

  List<OrientationRecommendation> _matchDoctors(
    List<RecommendedSpecialty> specialties,
    List<Doctor> doctors,
  ) {
    final list = <OrientationRecommendation>[];
    for (final spec in specialties) {
      final matching = doctors.where((d) {
        return _normalizeText(d.specialty) == _normalizeText(spec.name) ||
            _normalizeText(d.specialty).contains(_normalizeText(spec.name)) ||
            _normalizeText(spec.name).contains(_normalizeText(d.specialty));
      }).toList();

      list.add(OrientationRecommendation(
        specialty: spec,
        notebookDoctors: matching,
      ));
    }
    return list;
  }

  String? _findCanonicalMatch(String name, List<String> allowed) {
    final normName = _normalizeText(name);
    for (final candidate in allowed) {
      if (_normalizeText(candidate) == normName) {
        return candidate;
      }
    }
    for (final candidate in allowed) {
      if (_normalizeText(candidate).contains(normName) ||
          normName.contains(_normalizeText(candidate))) {
        return candidate;
      }
    }
    return null;
  }

  String _normalizeText(String input) {
    var s = input.toLowerCase();
    const withAccents = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
    const withoutAccents = 'aaaaaaceeeeiiiinooooouuuuyyoeae';
    for (int i = 0; i < withAccents.length; i++) {
      s = s.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Future<void> saveHistory({
    required String symptomsText,
    required OrientationResult result,
  }) async {
    final entry = OrientationHistoryEntry(
      id: const Uuid().v4(),
      date: DateTime.now().toIso8601String(),
      text: symptomsText.trim(),
      suggestedSpecialties:
          result.recommendedSpecialties.map((s) => s.name).toList(),
      urgency: result.urgency,
      advice: result.advice,
    );
    await localDataSource.saveHistory(entry);
  }

  @override
  Future<List<OrientationHistoryEntry>> getHistory() async {
    return await localDataSource.getHistory();
  }

  @override
  Future<void> clearHistory() async {
    await localDataSource.clearHistory();
  }

  @override
  Future<bool> hasUserConsented() async {
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    return prefs.getBool(OrientationConstants.consentPrefsKey) ?? false;
  }

  @override
  Future<void> setUserConsented(bool consented) async {
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(OrientationConstants.consentPrefsKey, consented);
  }
}
