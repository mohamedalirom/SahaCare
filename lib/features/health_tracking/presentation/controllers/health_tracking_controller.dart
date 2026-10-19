import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/services/auth_service.dart';
import '../../data/datasources/health_measurement_local_datasource.dart';
import '../../data/repositories/health_measurement_repository_impl.dart';
import '../../domain/entities/health_measurement.dart';
import '../../domain/repositories/health_measurement_repository.dart';
import '../../domain/usecases/add_measurement_usecase.dart';
import '../../domain/usecases/delete_measurement_usecase.dart';
import '../../domain/usecases/get_measurements_usecase.dart';
import '../../domain/usecases/update_measurement_usecase.dart';

// ============================================================================
// Providers d'infrastructure, Repository & Use Cases
// ============================================================================

final healthMeasurementLocalDataSourceProvider = Provider<HealthMeasurementLocalDataSource>((ref) {
  return HealthMeasurementLocalDataSourceImpl();
});

final healthMeasurementRepositoryProvider = Provider<HealthMeasurementRepository>((ref) {
  return HealthMeasurementRepositoryImpl(localDataSource: ref.watch(healthMeasurementLocalDataSourceProvider));
});

final getMeasurementsUseCaseProvider = Provider<GetMeasurementsUseCase>((ref) {
  return GetMeasurementsUseCase(ref.watch(healthMeasurementRepositoryProvider));
});

final addMeasurementUseCaseProvider = Provider<AddMeasurementUseCase>((ref) {
  return AddMeasurementUseCase(ref.watch(healthMeasurementRepositoryProvider));
});

final updateMeasurementUseCaseProvider = Provider<UpdateMeasurementUseCase>((ref) {
  return UpdateMeasurementUseCase(ref.watch(healthMeasurementRepositoryProvider));
});

final deleteMeasurementUseCaseProvider = Provider<DeleteMeasurementUseCase>((ref) {
  return DeleteMeasurementUseCase(ref.watch(healthMeasurementRepositoryProvider));
});

// ============================================================================
// Notifier du module Suivi de santé (CRUD) avec Riverpod
// ============================================================================

/// Liste des mesures de l'utilisateur connecté, de la plus récente à la plus ancienne
class HealthMeasurementsNotifier extends AsyncNotifier<List<HealthMeasurement>> {
  static const _uuid = Uuid();

  /// Identifiant de l'utilisateur dont les mesures sont chargées
  late String _userId;

  static String _currentUserId() => AuthService.instance.currentUser?.id ?? 'local';

  @override
  Future<List<HealthMeasurement>> build() async {
    _userId = _currentUserId();

    // Recharge les mesures si un autre utilisateur se connecte
    void onAuthChanged() {
      if (_currentUserId() != _userId) ref.invalidateSelf();
    }

    AuthService.instance.addListener(onAuthChanged);
    ref.onDispose(() => AuthService.instance.removeListener(onAuthChanged));

    return ref.read(getMeasurementsUseCaseProvider).call(_userId);
  }

  List<HealthMeasurement> get _current => state.value ?? const [];

  void _setSorted(List<HealthMeasurement> list) {
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    state = AsyncData(list);
  }

  /// Créer une mesure (Create). Renvoie la mesure enregistrée avec son identifiant.
  Future<HealthMeasurement> add(HealthMeasurement measurement) async {
    final saved = measurement.id.isEmpty ? measurement.copyWith(id: _uuid.v4()) : measurement;
    await ref.read(addMeasurementUseCaseProvider).call(_userId, saved);
    if (ref.mounted) _setSorted([..._current, saved]);
    return saved;
  }

  /// Modifier une mesure (Update)
  Future<void> edit(HealthMeasurement measurement) async {
    await ref.read(updateMeasurementUseCaseProvider).call(_userId, measurement);
    if (ref.mounted) _setSorted([for (final m in _current) m.id == measurement.id ? measurement : m]);
  }

  /// Supprimer une mesure (Delete). Retrait immédiat de l'écran, rétabli en cas d'échec.
  Future<void> delete(String id) async {
    final previous = _current;
    state = AsyncData(previous.where((m) => m.id != id).toList());
    try {
      await ref.read(deleteMeasurementUseCaseProvider).call(_userId, id);
    } catch (_) {
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
  }

  /// Réinsère une mesure supprimée (action « Annuler » du SnackBar)
  Future<void> restore(HealthMeasurement measurement) async {
    if (_current.any((m) => m.id == measurement.id)) return;
    await add(measurement);
  }
}

final healthMeasurementsProvider = AsyncNotifierProvider<HealthMeasurementsNotifier, List<HealthMeasurement>>(
  HealthMeasurementsNotifier.new,
);

/// Mesures d'un type donné (liste vide pendant le chargement)
final measurementsByTypeProvider = Provider.family<List<HealthMeasurement>, MeasurementType>((ref, type) {
  final all = ref.watch(healthMeasurementsProvider).value ?? const [];
  return all.where((m) => m.type == type).toList();
});

/// Mesure par identifiant (null si introuvable ou supprimée)
final measurementByIdProvider = Provider.family<HealthMeasurement?, String>((ref, id) {
  final all = ref.watch(healthMeasurementsProvider).value ?? const [];
  for (final m in all) {
    if (m.id == id) return m;
  }
  return null;
});
