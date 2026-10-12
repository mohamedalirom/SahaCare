import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';

/// Entrée d'affichage d'une frise (donnée déjà mise en forme, aucune action).
class TimelineEntry {
  const TimelineEntry({
    required this.title,
    required this.color,
    required this.icon,
    this.subtitle = '',
    this.dateLabel,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String? dateLabel;
  final String? badge;
  final Color color;
  final IconData icon;
}

/// Frise chronologique STRICTEMENT en lecture seule (TimelineTile).
///
/// Aucun `InkWell`, `Dismissible`, bouton ou callback : purement visuel.
class ReadOnlyTimeline extends StatelessWidget {
  const ReadOnlyTimeline({super.key, required this.entries});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = theme.colorScheme.onSurface.withValues(alpha: 0.15);

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          TimelineTile(
            isFirst: i == 0,
            isLast: i == entries.length - 1,
            indicatorStyle: IndicatorStyle(
              width: 34,
              height: 34,
              indicatorXY: 0.25,
              color: entries[i].color,
              iconStyle: IconStyle(iconData: entries[i].icon, color: Colors.white, fontSize: 18),
            ),
            beforeLineStyle: LineStyle(color: lineColor, thickness: 3),
            afterLineStyle: LineStyle(color: lineColor, thickness: 3),
            endChild: _EntryCard(entry: entries[i]),
          ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: entry.color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (entry.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: entry.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      entry.badge!,
                      style: TextStyle(color: entry.color, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            if (entry.subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(entry.subtitle, style: theme.textTheme.bodyMedium),
            ],
            if (entry.dateLabel != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_month_outlined, size: 14, color: entry.color),
                  const SizedBox(width: 4),
                  Text(
                    entry.dateLabel!,
                    style: TextStyle(color: entry.color, fontSize: 12, fontWeight: FontWeight.w600),
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
