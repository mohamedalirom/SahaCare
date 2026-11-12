import 'package:flutter/material.dart';

/// Boutons OAuth « Continuer avec Google / Apple » + séparateur « ou ».
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.onGoogle,
    required this.onApple,
    this.enabled = true,
    this.isGoogleLoading = false,
    this.isAppleLoading = false,
  });

  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final bool enabled;
  final bool isGoogleLoading;
  final bool isAppleLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('ou continuer avec', style: theme.textTheme.bodyMedium),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                label: 'Google',
                isLoading: isGoogleLoading,
                onPressed: enabled && !isGoogleLoading && !isAppleLoading ? onGoogle : null,
                leading: const Text(
                  'G',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4285F4)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialButton(
                label: 'Apple',
                isLoading: isAppleLoading,
                onPressed: enabled && !isGoogleLoading && !isAppleLoading ? onApple : null,
                leading: Icon(Icons.apple, size: 24, color: isDark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.onPressed,
    required this.leading,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget leading;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: onSurface,
        side: BorderSide(color: onSurface.withValues(alpha: 0.18)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
    );
  }
}
