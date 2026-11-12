import 'package:flutter/material.dart';

import '../../data/medication_repository.dart';
import '../../data/services/medication_access.dart';
import '../../data/services/medication_ownership_schema.dart';

/// Production routes never mount medical state before both session and storage
/// are ready. A generation change destroys every old child state.
class MedicationScopeGate extends StatefulWidget {
  const MedicationScopeGate({super.key, required this.child, this.repository});
  final Widget child;
  final MedicationRepository? repository;
  @override
  State<MedicationScopeGate> createState() => _MedicationScopeGateState();
}

class _MedicationScopeGateState extends State<MedicationScopeGate> {
  MedicationRepository get _repository =>
      widget.repository ?? MedicationRepository.instance;
  MedicationAccess get _access => _repository.access;
  Future<void>? _prepared;
  int? _generation;
  bool _retrying = false;
  @override
  void initState() {
    super.initState();
    _access.addListener(_changed);
    _prepare();
  }

  void _prepare() {
    if (_generation != _access.generation) {
      _generation = _access.generation;
      _prepared = null;
    }
    if (_access.ready && _prepared == null) {
      _prepared = Future<void>.sync(_repository.prepareStorage);
      // The future can fail before the next frame installs FutureBuilder's
      // listener. Consume that early unhandled notification, while retaining
      // the original future/error for FutureBuilder to display safely.
      _prepared!.ignore();
    }
  }

  void _changed() {
    if (!mounted) return;
    _prepare();
    setState(() {});
  }

  Future<void> _retry() async {
    if (!mounted || _retrying) return;
    setState(() {
      _retrying = true;
      _prepared = null;
    });
    try {
      // Session notifications call _changed/_prepare with the new generation.
      // Do not open storage a second time or adopt a later account after await.
      await _access.refresh();
    } finally {
      if (mounted) {
        setState(() {
          _retrying = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _access.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_access.ready) {
      return _message(
        _access.checking
            ? 'Vérification de la session…'
            : 'Connectez-vous pour accéder à vos traitements.',
        retry: !_access.checking,
      );
    }
    return FutureBuilder<void>(
      future: _prepared,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _message('Préparation de votre espace Médicaments…');
        }
        if (snapshot.hasError) {
          if (snapshot.error is MedicationMigrationRequired) {
            return _message(
              'Les anciennes données sont conservées. Une sauvegarde cohérente et une autorisation distincte sont nécessaires avant leur migration. Aucune migration personnelle n’a été effectuée.',
            );
          }
          return _message(
            'Accès Médicaments indisponible. Votre session ou votre stockage doit être vérifié.',
            retry: true,
          );
        }
        return KeyedSubtree(
          key: ValueKey('medication-scope-$_generation'),
          child: widget.child,
        );
      },
    );
  }

  Widget _message(String text, {bool retry = false}) => Scaffold(
    backgroundColor: const Color(0xFFF5FAF9),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                color: Color(0xFF0D9488),
                size: 36,
              ),
              const SizedBox(height: 16),
              Text(text, textAlign: TextAlign.center),
              if (retry)
                TextButton(
                  onPressed: _retrying ? null : _retry,
                  child: const Text('Réessayer'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Close only pageless dialogs/forms opened from this module. Other modules'
/// routes are never removed by a medication account transition.
class MedicationSessionNavigationObserver extends NavigatorObserver {
  MedicationSessionNavigationObserver({
    required this.isMedicationRoute,
    MedicationAccess? access,
  }) : access = access ?? MedicationAccess.instance {
    _generation = this.access.generation;
    this.access.addListener(_changed);
  }
  final bool Function() isMedicationRoute;
  final MedicationAccess access;
  late int _generation;
  final Set<Route<dynamic>> _medicalPopups = {};
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null &&
        route.settings is! Page &&
        (isMedicationRoute() || _medicalPopups.contains(previousRoute))) {
      _medicalPopups.add(route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _medicalPopups.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _medicalPopups.remove(route);
  }

  void _changed() {
    if (_generation == access.generation) return;
    _generation = access.generation;
    final popups = List<Route<dynamic>>.of(_medicalPopups);
    _medicalPopups.clear();
    Future.microtask(() {
      for (final route in popups) {
        if (route.isActive && !route.isFirst && route.navigator == navigator) {
          navigator?.removeRoute(route);
        }
      }
    });
  }

  void dispose() {
    access.removeListener(_changed);
  }
}
