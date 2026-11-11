import 'package:flutter/material.dart';

import '../../domain/services/medication_adherence.dart';
import 'medication_visuals.dart';

class AdherenceOverviewCard extends StatelessWidget {
  const AdherenceOverviewCard({
    super.key,
    required this.report,
    required this.formattedRate,
  });
  final AdherenceReport report;
  final String formattedRate;
  @override
  Widget build(BuildContext context) => MedicationSurface(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE4F7F1), Color(0xFFEDF6FB), Colors.white],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VOTRE RÉGULARITÉ',
                    style: TextStyle(
                      letterSpacing: 1.4,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: MedicationColors.teal,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Taux d’observance',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: MedicationColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            MedicationIllustration(size: 62),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          formattedRate,
          key: const ValueKey('adherence-rate'),
          style: const TextStyle(
            fontSize: 44,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            color: MedicationColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Taux d’observance $formattedRate',
          child: LinearProgressIndicator(
            value: (report.percentage ?? 0) / 100,
            color: MedicationColors.teal,
            backgroundColor: Colors.white,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${report.confirmed} prise(s) confirmée(s) sur ${report.denominator} prise(s) échue(s) enregistrée(s).',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: MedicationColors.muted,
          ),
        ),
        if (report.denominator == 0)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Aucune prise échue enregistrée : taux non calculable.',
              style: TextStyle(fontSize: 12, color: MedicationColors.muted),
            ),
          ),
        const SizedBox(height: 12),
        MedicationBadge(
          label:
              '${report.count(AdherenceStatus.future)} prise(s) à venir, hors taux.',
          color: MedicationColors.teal,
          icon: Icons.schedule_rounded,
        ),
      ],
    ),
  );
}

class AdherenceStatusGrid extends StatelessWidget {
  const AdherenceStatusGrid({
    super.key,
    required this.report,
    required this.colorFor,
  });
  final AdherenceReport report;
  final Color Function(AdherenceStatus) colorFor;
  static IconData iconFor(AdherenceStatus status) => switch (status) {
    AdherenceStatus.confirmed => Icons.task_alt_rounded,
    AdherenceStatus.ignored => Icons.do_not_disturb_on_outlined,
    AdherenceStatus.postponed => Icons.update_rounded,
    AdherenceStatus.late => Icons.hourglass_bottom_rounded,
    AdherenceStatus.missed => Icons.event_busy_outlined,
    AdherenceStatus.pending => Icons.more_time_rounded,
    AdherenceStatus.future => Icons.schedule_rounded,
  };
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 650
          ? 3
          : constraints.maxWidth < 240 ||
                MediaQuery.textScalerOf(context).scale(14) > 21
          ? 1
          : 2;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final status in [
            AdherenceStatus.confirmed,
            AdherenceStatus.ignored,
            AdherenceStatus.postponed,
            AdherenceStatus.late,
            AdherenceStatus.missed,
            AdherenceStatus.pending,
          ])
            SizedBox(
              width: width,
              child: Container(
                key: ValueKey('adherence-status-${status.name}'),
                constraints: const BoxConstraints(minHeight: 125),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorFor(status).withValues(alpha: .055),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorFor(status).withValues(alpha: .10),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(iconFor(status), size: 22, color: colorFor(status)),
                    const SizedBox(height: 12),
                    Text(
                      '${report.count(status)}',
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: MedicationColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MedicationColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
