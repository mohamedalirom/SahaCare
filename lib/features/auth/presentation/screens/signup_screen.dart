import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

import '../../../../core/widgets/custom_button.dart';
import '../../services/auth_service.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/social_auth_buttons.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _signup() async {
    if (_isLoading || _isGoogleLoading || _isAppleLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final auth = ref.read(authServiceProvider);
    try {
      final signedIn = await auth.signUp(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (signedIn) {
        context.go('/profil');
      } else {
        // Confirmation par e-mail requise
        context.pop();
        _showSuccess('Compte créé avec succès ! Confirmez votre e-mail puis connectez-vous.');
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
      await ref.read(authServiceProvider).signInWithOAuth(provider);
      if (mounted && ref.read(authServiceProvider).isAuthenticated) {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHeader(
                  title: 'Rejoignez SahaCare',
                  subtitle: 'Créez votre dossier médical en quelques secondes.',
                ),
                const SizedBox(height: 28),
                AuthTextField(
                  controller: _nameController,
                  label: 'Nom complet',
                  icon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Veuillez entrer votre nom' : null,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _passwordController,
                  label: 'Mot de passe',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Min. 6 caractères' : null,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirmer le mot de passe',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  validator: (v) => v != _passwordController.text ? 'Les mots de passe ne correspondent pas' : null,
                ),
                const SizedBox(height: 28),
                CustomButton(
                  label: 'S\'inscrire',
                  onPressed: (_isGoogleLoading || _isAppleLoading) ? null : _signup,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
