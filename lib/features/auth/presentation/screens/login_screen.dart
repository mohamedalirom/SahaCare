import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/auth_providers.dart';
import '../../services/auth_service.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/social_auth_buttons.dart';

enum _LoginMethod { password, magicLink }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _LoginMethod _method = _LoginMethod.password;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _magicLinkSent = false;
  bool _navigated = false;

  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _auth = ref.read(authServiceProvider);
    // Réagit aux connexions asynchrones (retour OAuth / Magic Link via deep link).
    _auth.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumeExistingSession());
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Session déjà ouverte au lancement : verrou biométrique si activé.
  Future<void> _resumeExistingSession() async {
    if (!_auth.isAuthenticated || _navigated || !mounted) return;
    final lockEnabled = await ref.read(biometricServiceProvider).isEnabled();
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go(lockEnabled ? '/biometric-lock' : '/profil');
  }

  void _onAuthChanged() {
    if (_auth.isAuthenticated && !_navigated && mounted) {
      _navigated = true;
      context.go('/profil');
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is AuthFailure ? error.message : 'Une erreur est survenue: $error';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  Future<void> _submit() async {
    if (_isLoading || _isGoogleLoading || _isAppleLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_method == _LoginMethod.password) {
        await _auth.signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (mounted && _auth.isAuthenticated && !_navigated) {
          _navigated = true;
          context.go('/profil');
        }
      } else {
        await _auth.signInWithOtp(email: _emailController.text);
        if (mounted) {
          setState(() => _magicLinkSent = true);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Lien magique envoyé ! Vérifiez votre boîte de réception.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _oauth(OAuthProvider provider) async {
    if (_isLoading || _isGoogleLoading || _isAppleLoading) return;
    setState(() {
      if (provider == OAuthProvider.google) {
        _isGoogleLoading = true;
      } else {
        _isAppleLoading = true;
      }
    });
    try {
      await _auth.signInWithOAuth(provider);
      if (mounted && _auth.isAuthenticated && !_navigated) {
        _navigated = true;
        context.go('/profil');
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
          _isAppleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMagic = _method == _LoginMethod.magicLink;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeader(
                    title: 'Bienvenue sur SahaCare',
                    subtitle: 'Connectez-vous pour accéder à votre dossier',
                  ),
                  const SizedBox(height: 28),
                  SegmentedButton<_LoginMethod>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _LoginMethod.password,
                        icon: Icon(Icons.lock_outline, size: 18),
                        label: Text('Mot de passe'),
                      ),
                      ButtonSegment(
                        value: _LoginMethod.magicLink,
                        icon: Icon(Icons.auto_awesome, size: 18),
                        label: Text('Magic Link'),
                      ),
                    ],
                    selected: {_method},
                    onSelectionChanged: (s) => setState(() {
                      _method = s.first;
                      _magicLinkSent = false;
                    }),
                  ),
                  const SizedBox(height: 20),
                  AuthTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: isMagic ? TextInputAction.done : TextInputAction.next,
                    validator: validateEmail,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: isMagic ? const SizedBox(width: double.infinity) : _passwordSection(),
                  ),
                  if (isMagic) ...[
                    const SizedBox(height: 12),
                    _MagicLinkHint(sent: _magicLinkSent),
                  ],
                  const SizedBox(height: 24),
                  CustomButton(
                    label: isMagic ? 'Envoyer le lien magique' : 'Se connecter',
                    icon: isMagic ? Icons.send_rounded : null,
                    onPressed: (_isGoogleLoading || _isAppleLoading) ? null : _submit,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),
                  SocialAuthButtons(
                    enabled: !_isLoading && !_isGoogleLoading && !_isAppleLoading,
                    isGoogleLoading: _isGoogleLoading,
                    isAppleLoading: _isAppleLoading,
                    onGoogle: () => _oauth(OAuthProvider.google),
                    onApple: () => _oauth(OAuthProvider.apple),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Nouveau sur SahaCare ?', style: theme.textTheme.bodyMedium),
                      TextButton(
                        onPressed: () => context.push('/signup'),
                        child: const Text(
                          'S\'inscrire',
                          style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        AuthTextField(
          controller: _passwordController,
          label: 'Mot de passe',
          icon: Icons.lock_outline,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Afficher' : 'Masquer',
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer votre mot de passe' : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/forgot-password'),
            child: const Text('Mot de passe oublié ?', style: TextStyle(color: AppTheme.secondaryColor)),
          ),
        ),
      ],
    );
  }
}

class _MagicLinkHint extends StatelessWidget {
  const _MagicLinkHint({required this.sent});
  final bool sent;

  @override
  Widget build(BuildContext context) {
    final color = sent ? AppTheme.accentColor : AppTheme.secondaryColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(sent ? Icons.mark_email_read_outlined : Icons.info_outline, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sent
                  ? 'Lien envoyé ! Ouvrez votre boîte mail et touchez le lien pour vous connecter.'
                  : 'Aucun mot de passe : nous vous envoyons un lien de connexion sécurisé par e-mail.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
