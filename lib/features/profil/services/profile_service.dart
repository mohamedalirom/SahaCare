import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../auth/services/auth_service.dart';
import '../domain/entities/user_profile.dart';

/// AccÃ¨s aux donnÃ©es du profil (table `profiles`, RLS : `id = auth.uid()`).
///
/// Seul ce service MODIFIE des donnÃ©es, et uniquement le profil
/// (dÃ©mographie, mode de vie, taille/poids, groupe sanguin).
class ProfileService {
  ProfileService({AuthService? auth}) : _auth = auth ?? AuthService.instance;

  static const String table = 'profiles';

  final AuthService _auth;

  // Stockage mÃ©moire du mode dÃ©mo (purgÃ© Ã  la dÃ©connexion).
  static UserProfile? _demoProfile;

  static void clearLocalCache() => _demoProfile = null;

  SessionUser get _user {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('Session expirÃ©e. Veuillez vous reconnecter.');
    return user;
  }

  Future<UserProfile> fetchProfile() async {
    final user = _user;

    if (!SupabaseConfig.isConfigured) {
      return _demoProfile ??= UserProfile(
        id: user.id,
        email: user.email,
        fullName: user.fullName ?? '',
        bloodGroup: 'O',
        rhesus: '+',
        heightCm: 180,
        weightKg: 75,
      );
    }

    final row = await Supabase.instance.client.from(table).select().eq('id', user.id).maybeSingle();
    if (row == null) {
      return UserProfile(id: user.id, email: user.email, fullName: user.fullName ?? '');
    }
    return UserProfile.fromMap(row, email: user.email);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final user = _user;
    // Garde-fou : on n'Ã©crit jamais le profil d'un autre utilisateur.
    if (profile.id != user.id) {
      throw const AuthFailure('Profil invalide pour la session courante.');
    }

    if (!SupabaseConfig.isConfigured) {
      _demoProfile = profile;
      return;
    }
    await Supabase.instance.client.from(table).upsert(profile.toMap());
  }
}
