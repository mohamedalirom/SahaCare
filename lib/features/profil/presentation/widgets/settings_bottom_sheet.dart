import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../i18n/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/settings_controller.dart';
import '../../services/pdf_export_service.dart';

/// A modern, highly structured Settings UI for the SahaCare application.
/// 
/// Trigger this bottom sheet from the profile screen's AppBar using:
/// SettingsBottomSheet.show(context);
class SettingsBottomSheet extends ConsumerStatefulWidget {
  const SettingsBottomSheet({super.key});

  /// Opens the Settings UI as a modal bottom sheet with DraggableScrollableSheet capabilities.
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Allows DraggableScrollableSheet to handle the border radius
      builder: (context) => const SettingsBottomSheet(),
    );
  }

  @override
  ConsumerState<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends ConsumerState<SettingsBottomSheet> {
  bool _isExportingPdf = false;
  bool _isResettingPassword = false;
  bool _isLoggingOut = false;

  Future<void> _resetPassword() async {
    if (_isResettingPassword) return;
    setState(() => _isResettingPassword = true);
    try {
      await ref.read(settingsControllerProvider.notifier).resetPassword(context);
    } finally {
      if (mounted) {
        setState(() => _isResettingPassword = false);
      }
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await ref.read(settingsControllerProvider.notifier).logout(context);
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le compte', style: TextStyle(color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cette action est irréversible. Toutes vos données médicales seront supprimées.'),
              const SizedBox(height: 16),
              const Text('Veuillez confirmer avec votre mot de passe :'),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                ref.read(settingsControllerProvider.notifier)
                   .deleteAccount(context, passwordController.text);
              },
              child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportMedicalRecordPdf() async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    try {
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
      await PdfExportService.exportAndShareMedicalRecord(
        context: context,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'exportation du PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  String _themeModeToString(ThemeMode mode, Translations l10n) {
    switch (mode) {
      case ThemeMode.light: return l10n.themeLight;
      case ThemeMode.dark: return l10n.themeDark;
      case ThemeMode.system: return l10n.themeSystem;
    }
  }

  String _localeToString(Locale loc) {
    switch (loc.languageCode) {
      case 'fr': return 'Français';
      case 'ar': return 'Arabe';
      case 'en': return 'Anglais';
      default: return 'Français';
    }
  }

  Locale _stringToLocale(String val) {
    switch (val) {
      case 'Arabe': return const Locale('ar');
      case 'Anglais': return const Locale('en');
      default: return const Locale('fr');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.t;
    
    // Watch global settings state
    final settingsState = ref.watch(settingsControllerProvider);
    final settingsNotifier = ref.read(settingsControllerProvider.notifier);

    final isBusy = _isResettingPassword || _isLoggingOut || _isExportingPdf;

    return IgnorePointer(
      ignoring: isBusy, // Block interaction only during active bottom sheet operations
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                // iOS/Material 3 standard drag handle indicator
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Sheet Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Text(
                        l10n.settings,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (isBusy)
                        const Padding(
                          padding: EdgeInsets.only(right: 16.0),
                          child: SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),

                // Scrollable Settings Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    children: [
                      // 1. Compte & Sécurité
                      _buildSectionHeader(context, l10n.accountSecurity),
                      _buildSectionCard(
                        children: [
                          _buildSwitchTile(
                            title: l10n.biometrics,
                            icon: Icons.fingerprint,
                            value: settingsState.biometricEnabled,
                            onChanged: (val) => settingsNotifier.toggleBiometrics(val, context),
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildActionTile(
                            title: l10n.changePassword,
                            icon: Icons.lock_reset,
                            isLoading: _isResettingPassword,
                            onTap: _resetPassword,
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildActionTile(
                            title: l10n.logout,
                            icon: Icons.logout,
                            isLoading: _isLoggingOut,
                            onTap: _logout,
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildActionTile(
                            title: l10n.deleteAccount,
                            icon: Icons.delete_forever,
                            isDestructive: true,
                            onTap: _showDeleteAccountDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 2. Préférences de l'Application
                      _buildSectionHeader(context, l10n.appPreferences),
                      _buildSectionCard(
                        children: [
                          _buildDropdownTile(
                            title: l10n.theme,
                            icon: Icons.brightness_6_outlined,
                            value: _themeModeToString(settingsState.themeMode, l10n),
                            items: [l10n.themeLight, l10n.themeDark, l10n.themeSystem],
                            onChanged: (val) {
                              if (val == l10n.themeLight) {
                                settingsNotifier.setThemeMode(ThemeMode.light);
                              } else if (val == l10n.themeDark) {
                                settingsNotifier.setThemeMode(ThemeMode.dark);
                              } else {
                                settingsNotifier.setThemeMode(ThemeMode.system);
                              }
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildDropdownTile(
                            title: l10n.language,
                            icon: Icons.language,
                            value: _localeToString(settingsState.locale),
                            items: const ['Français', 'Arabe', 'Anglais'],
                            onChanged: (val) {
                              if (val != null) settingsNotifier.setLocale(_stringToLocale(val));
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildSwitchTile(
                            title: l10n.metricSystem,
                            subtitle: l10n.metricSubtitle,
                            icon: Icons.straighten,
                            value: settingsState.isMetric,
                            onChanged: (val) => settingsNotifier.setMetric(val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 3. Confidentialité & Données Médicales
                      _buildSectionHeader(context, l10n.privacyMedical),
                      _buildSectionCard(
                        children: [
                          _buildSwitchTile(
                            title: l10n.profileVisibility,
                            subtitle: l10n.profileVisibilitySub,
                            icon: Icons.medical_services_outlined,
                            value: settingsState.profileVisibleToDoctors,
                            onChanged: (val) => settingsNotifier.toggleProfileVisibility(val, context),
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildActionTile(
                            title: l10n.exportRecord,
                            icon: Icons.file_download_outlined,
                            isLoading: _isExportingPdf,
                            onTap: _exportMedicalRecordPdf,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 4. À Propos
                      _buildSectionHeader(context, l10n.about),
                      _buildSectionCard(
                        children: [
                          _buildActionTile(
                            title: l10n.termsPrivacy,
                            icon: Icons.policy_outlined,
                            onTap: () async {
                              final url = Uri.parse('https://example.com/legal');
                              try {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
                                  );
                                }
                              }
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: Text(l10n.appVersion),
                            trailing: Text(
                              '1.0.0 (Build 42)',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48), // Padding for easy scrolling at the bottom
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Helper Widgets for Modern Settings Grouping ---

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      secondary: Icon(icon),
      activeThumbColor: Theme.of(context).colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isLoading = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? colorScheme.error : null;
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: color, 
          fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      trailing: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isDestructive 
              ? null 
              : Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: isLoading ? null : onTap,
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          alignment: Alignment.centerRight,
          icon: const Icon(Icons.arrow_drop_down),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
