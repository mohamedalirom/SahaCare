import '../entities/orientation_recommendation.dart';
import '../entities/orientation_result.dart';
import 'package:sahacare/features/appointments/orientation/data/models/orientation_history_entry.dart';

abstract class OrientationRepository {
  /// Récupère la liste des spécialités médicales autorisées (depuis sqflite)
  Future<List<String>> getAllowedSpecialties();

  /// Analyse les symptômes saisis, interroge Gemini (ou mode dégradé), valide et associe aux médecins
  Future<({OrientationResult result, List<OrientationRecommendation> recommendations})>
      orientSymptoms(String symptomsText);

  /// Analyse locale par mots-clés en mode dégradé (sans réseau / sans clé)
  Future<({OrientationResult result, List<OrientationRecommendation> recommendations})>
      orientSymptomsOffline(String symptomsText);

  /// Sauvegarde une analyse dans l'historique sqflite
  Future<void> saveHistory({
    required String symptomsText,
    required OrientationResult result,
  });

  /// Récupère l'historique des orientations
  Future<List<OrientationHistoryEntry>> getHistory();

  /// Efface tout l'historique
  Future<void> clearHistory();

  /// Vérifie si le patient a donné son consentement pour l'analyse IA
  Future<bool> hasUserConsented();

  /// Enregistre le consentement du patient
  Future<void> setUserConsented(bool consented);
}
