import 'package:flutter/material.dart';

/// Bandeau d'en-tête en dégradé affiché en haut des écrans du module
class SectionHeaderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const SectionHeaderCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final darker = Color.lerp(color, Colors.black, 0.18)!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, darker],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, height: 1.35, color: Colors.white.withValues(alpha: 0.88)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
