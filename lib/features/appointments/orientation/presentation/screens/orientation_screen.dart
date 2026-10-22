import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahacare/core/constants/app_constants.dart';
import 'package:sahacare/core/theme/app_theme.dart';
import 'package:sahacare/features/appointments/domain/entities/doctor.dart';
import 'package:sahacare/features/appointments/presentation/widgets/add_edit_doctor_dialog.dart';
import '../../data/constants/orientation_constants.dart';
import '../../domain/emergency_detector.dart';
import '../controllers/orientation_controller.dart';
import '../widgets/orientation_consent_bottom_sheet.dart';
import '../widgets/orientation_emergency_dialog.dart';
import '../widgets/orientation_result_view.dart';
import 'orientation_history_screen.dart';

class OrientationScreen extends ConsumerStatefulWidget {
  const OrientationScreen({super.key});

  @override
  ConsumerState<OrientationScreen> createState() => _OrientationScreenState();
}

class _OrientationScreenState extends ConsumerState<OrientationScreen> {
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _clarificationController =
      TextEditingController();

  final List<String> _examplePrompts = const [
    "Douleur au dos depuis une semaine après un faux mouvement",
    "Éruption cutanée rouge sur les bras qui démange fort",
    "Maux de tête fréquents le matin avec gêne visuelle",
    "Gencive gonflée et douloureuse lors du brossage",
  ];

  @override
  void dispose() {
    _symptomsController.dispose();
    _clarificationController.dispose();
    super.dispose();
  }

  void _submitSymptoms([bool bypassEmergency = false]) {
    final text = _symptomsController.text.trim();
    if (text.length < OrientationConstants.minSymptomsLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Veuillez décrire vos symptômes plus en détail (au moins 10 caractères).",
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    ref
        .read(orientationControllerProvider.notifier)
        .analyzeSymptoms(text, bypassEmergency: bypassEmergency);
  }

  void _submitClarification() {
    final answer = _clarificationController.text.trim();
    if (answer.isEmpty) return;
    FocusScope.of(context).unfocus();
    _clarificationController.clear();
    ref
        .read(orientationControllerProvider.notifier)
        .answerClarification(answer);
  }

  void _showConsentModal() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrientationConsentBottomSheet(
        onAccept: () {
          Navigator.of(ctx).pop();
          ref.read(orientationControllerProvider.notifier).giveConsent();
          if (_symptomsController.text.trim().length >=
              OrientationConstants.minSymptomsLength) {
            _submitSymptoms();
          }
        },
        onCancel: () {
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _showEmergencyDialog(EmergencyDetectionResult emergency) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OrientationEmergencyDialog(
        emergencyResult: emergency,
        onContinueAnyway: () {
          _submitSymptoms(true);
        },
      ),
    );
  }

  void _onBookAppointment(Doctor doctor) {
    context.push('/appointments/book', extra: doctor);
  }

  void _onAddDoctor(String specialty) {
    AddEditDoctorDialog.show(
      context,
      doctor: Doctor(
        id: '',
        fullName: '',
        specialty: specialty,
        hospitalOrClinic: '',
        address: '',
        phone: '',
        email: '',
        rating: 5.0,
        reviewsCount: 0,
        consultationFee: 60.0,
        bio: '',
      ),
    );
  }

  void _onSearchNearby(String specialty) {
    // Redirige vers la fonctionnalité "À proximité" avec la spécialité pré-sélectionnée
    context.push('/appointments/nearby', extra: specialty);
  }

  void _navigateToHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrientationHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orientationControllerProvider);
    final notifier = ref.read(orientationControllerProvider.notifier);

    // Écoute des changements d'état nécessitant des dialogues modaux
    ref.listen<OrientationState>(orientationControllerProvider, (prev, next) {
      if (next.step == OrientationStep.emergencyAlert &&
          next.emergencyResult != null &&
          prev?.step != OrientationStep.emergencyAlert) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showEmergencyDialog(next.emergencyResult!);
        });
      } else if (next.step == OrientationStep.consentRequired &&
          prev?.step != OrientationStep.consentRequired) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showConsentModal();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Orientation Médicale"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: "Historique",
            onPressed: _navigateToHistory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avertissement permanent de non-diagnostic
            _buildPermanentDisclaimer(),
            const SizedBox(height: 16),

            // Contenu selon l'étape actuelle
            if (state.isLoading)
              _buildLoadingView()
            else if (state.step == OrientationStep.needsMoreInfo)
              _buildClarificationView(state)
            else if (state.hasResult)
              OrientationResultView(
                result: state.orientationResult!,
                recommendations: state.recommendations,
                onBookAppointment: _onBookAppointment,
                onAddDoctor: _onAddDoctor,
                onSearchNearby: _onSearchNearby,
                onReset: () {
                  _symptomsController.clear();
                  notifier.reset();
                },
                onViewHistory: _navigateToHistory,
              )
            else
              _buildInputSection(state),
          ],
        ),
      ),
    );
  }

  Widget _buildPermanentDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined,
              size: 20, color: Colors.amber.shade900),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Cette suggestion est une orientation générale, pas un diagnostic. Elle ne remplace pas l'avis d'un médecin. En cas d'urgence, appelez le ${AppConstants.emergencyPhone}.",
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.amber.shade900,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(OrientationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Carte explicative
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.chat_bubble_outline,
                      color: AppTheme.primaryColor, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Quelle spécialité consulter ?",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Décrivez vos symptômes en langage naturel. Notre assistant d'orientation vous guidera vers la spécialité médicale la plus adaptée parmi celles disponibles.",
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Champ de saisie multiligne
              TextField(
                controller: _symptomsController,
                maxLines: 4,
                maxLength: OrientationConstants.maxSymptomsLength,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText:
                      "Ex : J'ai une douleur persistante dans le bas du dos depuis 4 jours...",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              // Exemples rapides
              const Text(
                "Exemples fréquents :",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _examplePrompts.map((example) {
                  return ActionChip(
                    label: Text(example),
                    labelStyle: const TextStyle(fontSize: 11.5),
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide(color: Colors.grey.shade300),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _symptomsController.text = example;
                      setState(() {});
                    },
                  );
                }).toList(),
              ),

              // Affichage d'erreur éventuelle
              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline,
                              size: 18, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (state.isNetworkError ||
                          state.isQuotaExceeded ||
                          state.isKeyMissing) ...[
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(orientationControllerProvider.notifier)
                                .useDegradedMode(_symptomsController.text);
                          },
                          icon: const Icon(Icons.offline_bolt, size: 16),
                          label: const Text("Essayer l'orientation hors-ligne"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Bouton principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _symptomsController.text.trim().length >=
                          OrientationConstants.minSymptomsLength
                      ? () => _submitSymptoms()
                      : null,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text(
                    "Trouver la bonne spécialité",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          const Text(
            "Analyse en cours...",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "L'assistant d'orientation consulte la liste des spécialités disponibles pour vous recommander la plus adaptée.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildClarificationView(OrientationState state) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.help_outline,
                      color: Colors.orange.shade800, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Précision nécessaire",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              state.clarificationQuestion ??
                  "Pouvez-vous préciser vos symptômes pour affiner l'orientation ?",
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clarificationController,
              maxLines: 3,
              maxLength: 250,
              decoration: InputDecoration(
                hintText: "Votre réponse ici...",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitClarification,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Valider ma précision"),
            ),
          ],
        ),
      ),
    );
  }
}
