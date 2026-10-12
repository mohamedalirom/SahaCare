
import '../../../core/config/supabase_config.dart';
import '../../auth/services/auth_service.dart';
import '../domain/entities/medical_history.dart';
import '../domain/repositories/medical_repository.dart';

/// Lecteur LECTURE SEULE du dossier médical (maladies, allergies, antécédents).
///
/// ⚠️ Contrainte d'architecture : cette classe n'expose que des `select`.
/// Aucune écriture (insert / update / delete / upsert) ne doit jamais y être
/// ajoutée : ces tables sont alimentées par d'autres modules.
class MedicalHistoryReader {
  MedicalHistoryReader({AuthService? auth}) : _auth = auth ?? AuthService.instance;

  // Noms de tables partagés avec les autres modules (à ajuster ici uniquement).
  static const String diseasesTable = 'diseases';
  static const String allergiesTable = 'allergies';
  static const String historyTable = 'medical_history';

  final AuthService _auth;

  Future<MedicalHistory> fetch() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('Session expirée. Veuillez vous reconnecter.');

    if (!SupabaseConfig.isConfigured) return _demoData;

    // Privacy-first: read exclusively from local SQLite repository
    return MedicalRepository().getMedicalHistory(user.id);
  }

  // Données d'exemple du mode démo (debug sans backend).
  static final MedicalHistory _demoData = MedicalHistory(
    diseases: [
      Disease(id: 'd1', name: 'Hypertension', diagnosedAt: DateTime(2021, 3), isChronic: true),
      Disease(id: 'd2', name: 'Diabète de type 2', diagnosedAt: DateTime(2022, 9), isChronic: true),
    ],
    allergies: const [
      Allergy(id: 'a1', name: 'Pénicilline', severity: AllergySeverity.severe, kind: AllergyKind.medication),
      Allergy(id: 'a2', name: 'Arachides', severity: AllergySeverity.moderate, kind: AllergyKind.food),
      Allergy(id: 'a3', name: 'Pollen', severity: AllergySeverity.mild, kind: AllergyKind.other),
    ],
    history: [
      MedicalHistoryEntry(
        id: 'h1',
        title: 'Fracture du poignet',
        description: 'Plâtre pendant 4 semaines',
        date: DateTime(2018, 8),
      ),
      MedicalHistoryEntry(
        id: 'h2',
        title: 'Appendicectomie',
        description: 'Opération chirurgicale',
        date: DateTime(2015, 5),
      ),
    ],
  );
}
