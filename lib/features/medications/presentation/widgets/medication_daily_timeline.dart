import 'package:flutter/material.dart';

import '../../domain/entities/medication_occurrence.dart';
import 'medication_calendar_grid.dart' show medicationOccurrenceColor;

const _teal = Color(0xFF0D9488);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

class MedicationDailyTimeline extends StatelessWidget {
  const MedicationDailyTimeline({
    super.key,
    required this.occurrences,
    required this.busyOccurrenceIds,
    required this.onOpen,
    required this.onTaken,
    required this.onPostpone,
    required this.onIgnore,
  });

  final List<MedicationOccurrence> occurrences;
  final Set<int> busyOccurrenceIds;
  final ValueChanged<int> onOpen;
  final ValueChanged<MedicationOccurrence> onTaken;
  final ValueChanged<MedicationOccurrence> onPostpone;
  final ValueChanged<MedicationOccurrence> onIgnore;

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEAF0F4)),
        ),
        child: const Column(
          children: [
            Icon(Icons.event_available_outlined, color: _muted, size: 28),
            SizedBox(height: 9),
            Text(
              'Aucune prise prévue pour cette journée.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < occurrences.length; index++)
          _TimelineOccurrence(
            occurrence: occurrences[index],
            isLast: index == occurrences.length - 1,
            busy: busyOccurrenceIds.contains(occurrences[index].id),
            onOpen: () => onOpen(occurrences[index].medicationId),
            onTaken: () => onTaken(occurrences[index]),
            onPostpone: () => onPostpone(occurrences[index]),
            onIgnore: () => onIgnore(occurrences[index]),
          ),
      ],
    );
  }
}

class _TimelineOccurrence extends StatelessWidget {
  const _TimelineOccurrence({
    required this.occurrence,
    required this.isLast,
    required this.busy,
    required this.onOpen,
    required this.onTaken,
    required this.onPostpone,
    required this.onIgnore,
  });

  final MedicationOccurrence occurrence;
  final bool isLast;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onTaken;
  final VoidCallback onPostpone;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final canConfirm =
        occurrence.status == MedicationOccurrenceStatus.scheduled ||
        occurrence.status == MedicationOccurrenceStatus.postponed;
    final statusColor = medicationOccurrenceColor(occurrence);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              occurrence.effectiveTime,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 18,
          child: Column(
            children: [
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.only(top: 20),
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.22),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: canConfirm ? 140 : 70,
                  margin: const EdgeInsets.only(top: 5),
                  color: const Color(0xFFDCEAE8),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MedicationOccurrenceCard(
              occurrence: occurrence,
              busy: busy,
              statusColor: statusColor,
              onOpen: onOpen,
              onTaken: onTaken,
              onPostpone: onPostpone,
              onIgnore: onIgnore,
              canConfirm: canConfirm,
            ),
          ),
        ),
      ],
    );
  }
}

class _MedicationOccurrenceCard extends StatelessWidget {
  const _MedicationOccurrenceCard({
    required this.occurrence,
    required this.busy,
    required this.statusColor,
    required this.onOpen,
    required this.onTaken,
    required this.onPostpone,
    required this.onIgnore,
    required this.canConfirm,
  });

  final MedicationOccurrence occurrence;
  final bool busy;
  final Color statusColor;
  final VoidCallback onOpen;
  final VoidCallback onTaken;
  final VoidCallback onPostpone;
  final VoidCallback onIgnore;
  final bool canConfirm;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEAF0F4)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.035),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F5),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  color: _teal,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occurrence.medicationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      occurrence.dosage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                occurrence.statusLabel(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            if (occurrence.status == MedicationOccurrenceStatus.postponed)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  _formatDate(occurrence.effectiveDate),
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ),
          ],
        ),
        if (busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(color: _teal),
        ] else if (canConfirm) ...[
          const SizedBox(height: 7),
          Wrap(
            spacing: 2,
            runSpacing: 0,
            children: [
              TextButton.icon(
                onPressed: onTaken,
                icon: const Icon(Icons.check_circle_outline, size: 17),
                label: const Text('Pris'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF15803D),
                  minimumSize: const Size(0, 40),
                ),
              ),
              TextButton.icon(
                onPressed: onPostpone,
                icon: const Icon(Icons.snooze_outlined, size: 17),
                label: const Text('Reporter'),
                style: TextButton.styleFrom(
                  foregroundColor: _muted,
                  minimumSize: const Size(0, 40),
                ),
              ),
              TextButton.icon(
                onPressed: onIgnore,
                icon: const Icon(Icons.close, size: 17),
                label: const Text('Ignorer'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB91C1C),
                  minimumSize: const Size(0, 40),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
