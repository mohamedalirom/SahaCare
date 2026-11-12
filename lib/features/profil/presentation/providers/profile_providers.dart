import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/services/auth_service.dart';
import '../../domain/entities/medical_history.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/medical_repository.dart';
import '../../services/medical_history_reader.dart';
import '../../services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService());

final medicalHistoryReaderProvider = Provider<MedicalHistoryReader>((ref) => MedicalHistoryReader());

/// Profil éditable de l'utilisateur connecté.
class ProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() => ref.read(profileServiceProvider).fetchProfile();

  Future<void> save(UserProfile profile) async {
    await ref.read(profileServiceProvider).saveProfile(profile);
    state = AsyncData(profile);
  }
}

final profileProvider = AsyncNotifierProvider.autoDispose<ProfileNotifier, UserProfile>(ProfileNotifier.new);

final medicalRepositoryProvider = Provider<MedicalRepository>((ref) => MedicalRepository());

/// Dossier médical — lecture depuis SQLite, mutations via l'outbox.
/// Chaque mutation attend la transaction locale puis recharge l'état.
class MedicalHistoryNotifier extends AsyncNotifier<MedicalHistory> {
  MedicalRepository get _repo => ref.read(medicalRepositoryProvider);

  String get _userId {
    final user = AuthService.instance.currentUser;
    if (user == null) throw const AuthFailure('Session expirée. Veuillez vous reconnecter.');
    return user.id;
  }

  @override
  Future<MedicalHistory> build() => _repo.getMedicalHistory(_userId);

  Future<void> _reload() async {
    final data = await _repo.getMedicalHistory(_userId);
    state = AsyncData(data);
  }

  Future<void> addDisease({required String name, DateTime? diagnosedAt, bool isChronic = false}) async {
    await _repo.addDisease(_userId, name: name, diagnosedAt: diagnosedAt, isChronic: isChronic);
    await _reload();
  }

  Future<void> updateDisease(Disease d) async {
    await _repo.updateDisease(_userId, d);
    await _reload();
  }

  Future<void> deleteDisease(String id) async {
    await _repo.deleteDisease(_userId, id);
    await _reload();
  }

  Future<void> addAllergy({
    required String name,
    required AllergySeverity severity,
    required AllergyKind kind,
  }) async {
    await _repo.addAllergy(_userId, name: name, severity: severity, kind: kind);
    await _reload();
  }

  Future<void> updateAllergy(Allergy a) async {
    await _repo.updateAllergy(_userId, a);
    await _reload();
  }

  Future<void> deleteAllergy(String id) async {
    await _repo.deleteAllergy(_userId, id);
    await _reload();
  }

  Future<void> addHistoryEntry({required String title, String description = '', DateTime? date}) async {
    await _repo.addHistoryEntry(_userId, title: title, description: description, date: date);
    await _reload();
  }

  Future<void> updateHistoryEntry(MedicalHistoryEntry e) async {
    await _repo.updateHistoryEntry(_userId, e);
    await _reload();
  }

  Future<void> deleteHistoryEntry(String id) async {
    await _repo.deleteHistoryEntry(_userId, id);
    await _reload();
  }
}

final medicalHistoryProvider =
    AsyncNotifierProvider.autoDispose<MedicalHistoryNotifier, MedicalHistory>(MedicalHistoryNotifier.new);
