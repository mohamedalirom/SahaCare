import 'package:flutter/material.dart';
import '../../domain/entities/appointment.dart';

/// Badge indiquant le statut d'un rendez-vous médical
class AppointmentStatusBadge extends StatelessWidget {
  final AppointmentStatus status;

  const AppointmentStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case AppointmentStatus.upcoming:
        bg = const Color(0xFFE0F2FE); // Bleu doux
        fg = const Color(0xFF0284C7);
        icon = Icons.schedule_rounded;
        break;
      case AppointmentStatus.completed:
        bg = const Color(0xFFDCFCE7); // Vert santé
        fg = const Color(0xFF16A34A);
        icon = Icons.check_circle_outline_rounded;
        break;
      case AppointmentStatus.cancelled:
        bg = const Color(0xFFFEE2E2); // Rouge alerte
        fg = const Color(0xFFDC2626);
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
