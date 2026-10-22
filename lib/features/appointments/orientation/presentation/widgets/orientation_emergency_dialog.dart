import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sahacare/core/constants/app_constants.dart';
import '../../domain/emergency_detector.dart';

/// Modal d'alerte rouge en cas d'urgence médicale ou de détresse psychologique détectée
class OrientationEmergencyDialog extends StatelessWidget {
  final EmergencyDetectionResult emergencyResult;
  final VoidCallback onContinueAnyway;

  const OrientationEmergencyDialog({
    super.key,
    required this.emergencyResult,
    required this.onContinueAnyway,
  });

  Future<void> _callEmergency() async {
    final uri = Uri.parse('tel:${AppConstants.emergencyPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuicidal = emergencyResult.isSuicidal;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isSuicidal
                      ? Colors.purple.shade50
                      : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuicidal ? Icons.favorite : Icons.warning_amber_rounded,
                  size: 40,
                  color: isSuicidal ? Colors.purple : Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isSuicidal
                    ? "Vous n'êtes pas seul(e)"
                    : "Attention : Urgence médicale potentielle",
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSuicidal ? Colors.purple.shade900 : Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isSuicidal
                    ? "Si vous traversez une période difficile ou ressentez le besoin d'en parler, ne restez pas seul(e). Contactez immédiatement un proche ou les services d'urgence."
                    : "Votre description mentionne des symptômes qui pourraient nécessiter une prise en charge médicale immédiate.\n\nN'attendez pas un rendez-vous ordinaire : contactez les secours.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _callEmergency,
                  icon: const Icon(Icons.phone_in_talk, color: Colors.white),
                  label: Text(
                    "Appeler le ${AppConstants.emergencyPhoneName}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isSuicidal ? Colors.purple.shade700 : Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onContinueAnyway();
                },
                child: Text(
                  "Je comprends, continuer quand même",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
