import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/saha_intelligence_controller.dart';
import 'health_palette.dart';
import 'watch_alert_banner.dart';

/// Accès à Saha Intelligence et à la montre connectée depuis le tableau de bord
class SahaIntelligenceEntry extends ConsumerWidget {
  const SahaIntelligenceEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(healthAnalysisProvider);
    final watch = ref.watch(connectedWatchProvider);
    final unusual = analysis?.unusualCount ?? 0;

    return Column(
      children: [
        if (watch.alert != null) ...[
          WatchAlertBanner(
            alert: watch.alert!,
            onDismiss: ref.read(connectedWatchProvider.notifier).dismissAlert,
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: _EntryTile(
                icon: Icons.auto_awesome_rounded,
                title: 'Saha Intelligence',
                subtitle: unusual == 0 ? 'Analyse et résumé IA' : '$unusual valeur(s) inhabituelle(s)',
                highlight: unusual > 0,
                onTap: () => context.push('/health-tracking/intelligence'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _EntryTile(
                icon: Icons.watch_rounded,
                title: 'Montre connectée',
                subtitle: watch.connected ? '${watch.current?.round() ?? '--'} bpm en direct' : 'Non connectée',
                highlight: watch.alert != null,
                onTap: () => context.push('/health-tracking/watch'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback onTap;

  const _EntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: context.healthSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: highlight ? const Color(0xFFD97706) : context.healthBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: primary, size: 22),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: context.healthText),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: context.healthTextSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
