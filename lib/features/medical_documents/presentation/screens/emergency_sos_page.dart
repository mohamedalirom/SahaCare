import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../appointments/nearby/data/datasources/location_service.dart';
import '../../data/services/emergency_alert_service.dart';
import '../../domain/entities/emergency_contact.dart';
import '../providers/medical_documents_providers.dart';
import 'add_emergency_contact_page.dart';

const _red = Color(0xFFDC2626);

/// Écran SOS : localise l'utilisateur et envoie sa position à ses contacts d'urgence.
class EmergencySosPage extends ConsumerStatefulWidget {
  const EmergencySosPage({super.key});

  @override
  ConsumerState<EmergencySosPage> createState() => _EmergencySosPageState();
}

class _EmergencySosPageState extends ConsumerState<EmergencySosPage> {
  AlertLocation? _location;
  LocationCustomException? _locationError;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final location = await ref.read(emergencyAlertServiceProvider).currentLocation();
      if (mounted) setState(() => _location = location);
    } on LocationCustomException catch (e) {
      if (mounted) setState(() => _locationError = e);
    } catch (e) {
      if (mounted) {
        setState(() => _locationError = LocationCustomException('Position introuvable : $e', LocationErrorType.unknown));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String _message() {
    final profile = ref.read(emergencyProfileProvider);
    return EmergencyAlertService.buildMessage(
      senderName: profile.fullName,
      location: _location,
      bloodGroup: profile.bloodGroup,
      allergies: profile.allergies,
    );
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? _red : null));
  }

  Future<void> _sendSms(List<EmergencyContact> contacts) async {
    final ok = await ref
        .read(emergencyAlertServiceProvider)
        .sendSms([for (final c in contacts) c.phone], _message());
    if (!ok && mounted) _snack('Impossible d\'ouvrir l\'application SMS.', error: true);
  }

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(text: _message(), subject: 'URGENCE SahaCare'));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _message()));
    if (mounted) _snack('Message d\'alerte copié');
  }

  Future<void> _callSamu() async {
    final ok = await ref.read(emergencyAlertServiceProvider).call(samuNumber);
    if (!ok && mounted) _snack('Appel impossible depuis cet appareil. Composez le $samuNumber.', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(emergencyAlertServiceProvider);
    final contacts = ref.watch(emergencyContactsProvider);
    // Contact principal en premier
    final recipients = [...contacts]..sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));

    return Scaffold(
      appBar: AppBar(title: const Text('SOS urgence')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _LocationCard(
            locating: _locating,
            location: _location,
            error: _locationError,
            onRetry: _locate,
            onOpenSettings: _locationError?.type == LocationErrorType.serviceDisabled
                ? service.openLocationSettings
                : _locationError?.type == LocationErrorType.permissionDeniedForever
                ? service.openAppSettings
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            recipients.isEmpty ? 'Aucun destinataire' : 'Destinataires (${recipients.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          if (recipients.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded, color: _red),
                title: const Text('Ajoutez un contact d\'urgence'),
                subtitle: const Text('Il recevra votre position en cas d\'alerte.'),
                onTap: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEmergencyContactPage())),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final c in recipients)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: _red.withValues(alpha: 0.1),
                        child: Text(c.initials, style: const TextStyle(fontSize: 12, color: _red)),
                      ),
                      title: Text(c.name),
                      subtitle: Text('${c.relation} · ${c.phone}'),
                      trailing: c.isPrimary
                          ? const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20)
                          : null,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Message envoyé',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SelectableText(_message(), style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
          const SizedBox(height: 20),
          if (service.canSendSms)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: recipients.isEmpty || _locating ? null : () => _sendSms(recipients),
              icon: const Icon(Icons.sms_rounded),
              label: const Text('Envoyer ma position par SMS'),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _locating ? null : _share,
              icon: const Icon(Icons.share_location_rounded),
              label: const Text('Partager ma position'),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (service.canSendSms) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _share,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Partager'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _locating ? null : _copy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copier'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _red,
              side: const BorderSide(color: _red),
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _callSamu,
            icon: const Icon(Icons.call_rounded),
            label: const Text('Appeler le SAMU ($samuNumber)'),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final bool locating;
  final AlertLocation? location;
  final LocationCustomException? error;
  final VoidCallback onRetry;
  final Future<bool> Function()? onOpenSettings;

  const _LocationCard({
    required this.locating,
    required this.location,
    required this.error,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String title;
    final String subtitle;

    if (locating) {
      icon = Icons.my_location_rounded;
      color = const Color(0xFF0284C7);
      title = 'Localisation en cours…';
      subtitle = 'Autorisez l\'accès à votre position si le téléphone le demande.';
    } else if (location != null) {
      icon = Icons.location_on_rounded;
      color = const Color(0xFF16A34A);
      title = 'Position trouvée';
      subtitle = [
        '${location!.latitude.toStringAsFixed(5)}, ${location!.longitude.toStringAsFixed(5)}',
        if (location!.accuracy != null) 'précision ~${location!.accuracy!.round()} m',
      ].join(' · ');
    } else {
      icon = Icons.location_off_rounded;
      color = _red;
      title = 'Position indisponible';
      subtitle = '${error?.message ?? 'Erreur inconnue.'}\nL\'alerte peut quand même être envoyée sans position.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (locating)
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))
              else
                Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                  ],
                ),
              ),
            ],
          ),
          if (!locating)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                children: [
                  if (onOpenSettings != null)
                    TextButton(onPressed: onOpenSettings, child: const Text('Paramètres')),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(location != null ? 'Actualiser' : 'Réessayer'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
