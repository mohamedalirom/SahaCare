import 'package:flutter/material.dart';

import '../../data/services/medication_notification_service.dart';

class MedicationNotificationPanel extends StatelessWidget {
  const MedicationNotificationPanel({super.key, this.service});
  final MedicationNotificationService? service;

  @override
  Widget build(BuildContext context) {
    final notifications = service ?? MedicationNotificationService.instance;
    return ValueListenableBuilder<MedicationNotificationState>(
      valueListenable: notifications,
      builder: (context, state, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications système',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              style: const TextStyle(color: Color(0xFF0F172A)),
            ),
            if (state.status != MedicationNotificationStatus.unsupported &&
                state.status != MedicationNotificationStatus.checking) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        notifications.synchronize(requestPermission: true),
                    icon: const Icon(Icons.notifications_outlined),
                    label: Text(
                      state.status == MedicationNotificationStatus.denied
                          ? 'Autoriser les notifications'
                          : 'Vérifier / réessayer',
                    ),
                  ),
                  if (state.status == MedicationNotificationStatus.scheduled &&
                      !state.exact)
                    TextButton(
                      onPressed: () =>
                          notifications.synchronize(requestExact: true),
                      child: const Text('Autoriser les horaires précis'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
