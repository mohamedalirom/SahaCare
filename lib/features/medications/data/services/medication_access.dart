import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../auth/services/auth_service.dart';

class MedicationAccessDenied implements Exception {
  const MedicationAccessDenied();
  @override
  String toString() =>
      'Session Médicaments absente, expirée ou modifiée. Reconnectez-vous.';
}

/// Trusted adapter boundary. Production uses the SDK; isolated tests inject a
/// fake authority here, never an owner supplied to a repository method/widget.
abstract interface class MedicationSessionAuthority {
  String? get stamp;
  MedicationIdentity? get initialVerifiedIdentity;
  Future<MedicationIdentity?> verify();
}

class MedicationIdentity {
  const MedicationIdentity({
    required this.owner,
    required this.expiresAt,
    this.demo = false,
  });
  final String owner;
  final DateTime expiresAt;
  final bool demo;
}

class _SupabaseMedicationAuthority implements MedicationSessionAuthority {
  @override
  MedicationIdentity? get initialVerifiedIdentity => null;
  @override
  String? get stamp {
    if (SupabaseConfig.isDemoMode) {
      final id = AuthService.instance.currentUser?.id;
      return id == 'local-demo-user' || id == 'demo-user' ? 'demo:$id' : null;
    }
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.expiresAt == null || session.isExpired) {
        return null;
      }
      return session.accessToken;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MedicationIdentity?> verify() async {
    final credential = stamp;
    if (credential == null) return null;
    if (SupabaseConfig.isDemoMode) {
      return MedicationIdentity(
        owner: 'demo:local',
        demo: true,
        expiresAt: DateTime.utc(9999),
      );
    }
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session == null) return null;
    final response = await auth.getUser(credential);
    if (stamp != credential || response.user?.id != session.user.id) {
      return null;
    }
    final uri = Uri.parse(SupabaseConfig.url);
    if (uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final project = '${uri.origin}${uri.normalizePath().path}'.replaceAll(
      RegExp(r'/+$'),
      '',
    );
    return MedicationIdentity(
      owner: 'supabase:$project:${response.user!.id}',
      expiresAt: DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000),
    );
  }
}

class MedicationLease {
  MedicationLease._(
    this.access,
    this.owner,
    this.generation,
    this.notificationScope,
    this.demo,
  );
  final MedicationAccess access;
  final String owner;
  final int generation;
  final String notificationScope;
  final bool demo;
  void check() {
    access.check(this);
  }
}

class MedicationAccess extends ChangeNotifier {
  MedicationAccess({required this.authority, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    // A trusted test/previously-verified adapter may supply this proof. The real
    // Supabase adapter never treats restored local state as verified identity.
    final initial = authority.initialVerifiedIdentity;
    if (initial != null && _clock().isBefore(initial.expiresAt)) {
      _identity = initial;
      _verifiedStamp = authority.stamp;
      _notificationScope = _nonce();
      if (!initial.demo) {
        _expiration = Timer(initial.expiresAt.difference(_clock()), invalidate);
      }
    }
  }
  static String _nonce() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  static final instance = MedicationAccess(
    authority: _SupabaseMedicationAuthority(),
  );
  final MedicationSessionAuthority authority;
  final DateTime Function() _clock;
  MedicationIdentity? _identity;
  String? _verifiedStamp;
  int _generation = 0;
  String _notificationScope = '';
  bool _started = false;
  bool checking = false;
  Timer? _expiration;
  Future<void>? _refreshing;
  int get generation => _generation;
  bool get ready =>
      _identity != null &&
      _verifiedStamp != null &&
      authority.stamp == _verifiedStamp &&
      _clock().isBefore(_identity!.expiresAt);
  bool get demo => ready && _identity!.demo;
  void start() {
    if (_started) return;
    _started = true;
    AuthService.instance.addListener(_authChanged);
    unawaited(refresh());
  }

  void _authChanged() {
    if (authority.stamp != _verifiedStamp) unawaited(refresh());
  }

  void invalidate() {
    _generation++;
    _identity = null;
    _verifiedStamp = null;
    _expiration?.cancel();
    checking = false;
    notifyListeners();
  }

  Future<void> ensureReady() =>
      ready ? Future.value() : (_refreshing ?? refresh());
  Future<void> refresh() {
    final work = _refresh();
    _refreshing = work;
    return work;
  }

  Future<void> _refresh() async {
    invalidate();
    final generation = _generation, stamp = authority.stamp;
    if (stamp == null) return;
    checking = true;
    notifyListeners();
    try {
      final identity = await authority.verify();
      if (generation != _generation || stamp != authority.stamp) return;
      if (identity == null ||
          identity.owner.isEmpty ||
          !_clock().isBefore(identity.expiresAt)) {
        return;
      }
      _identity = identity;
      _verifiedStamp = stamp;
      _notificationScope = List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      if (!identity.demo) {
        _expiration = Timer(
          identity.expiresAt.difference(_clock()),
          invalidate,
        );
      }
    } catch (_) {
      /* No token or personal metadata in diagnostics. */
    } finally {
      if (generation == _generation) {
        checking = false;
        notifyListeners();
      }
    }
  }

  MedicationLease capture() {
    if (!ready) throw const MedicationAccessDenied();
    return MedicationLease._(
      this,
      _identity!.owner,
      _generation,
      _notificationScope,
      _identity!.demo,
    );
  }

  void check(MedicationLease lease) {
    if (!identical(lease.access, this) ||
        !ready ||
        lease.generation != _generation ||
        lease.owner != _identity!.owner) {
      throw const MedicationAccessDenied();
    }
  }

  @override
  void dispose() {
    if (_started) AuthService.instance.removeListener(_authChanged);
    _expiration?.cancel();
    super.dispose();
  }
}
