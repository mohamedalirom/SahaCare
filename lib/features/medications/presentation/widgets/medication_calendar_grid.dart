import 'package:flutter/material.dart';

import '../../domain/entities/medication_occurrence.dart';

const _teal = Color(0xFF0D9488);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

const _weekdayLabels = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];

Color medicationOccurrenceColor(MedicationOccurrence occurrence) =>
    switch (occurrence.status) {
      MedicationOccurrenceStatus.taken => const Color(0xFF16A34A),
      MedicationOccurrenceStatus.ignored => const Color(0xFFDC2626),
      MedicationOccurrenceStatus.scheduled ||
      MedicationOccurrenceStatus.postponed => const Color(0xFFF59E0B),
    };

class MedicationWeekSelector extends StatelessWidget {
  const MedicationWeekSelector({
    super.key,
    required this.weekStart,
    required this.selectedDate,
    required this.occurrences,
    required this.onSelected,
  });

  final DateTime weekStart;
  final DateTime selectedDate;
  final List<MedicationOccurrence> occurrences;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    return Row(
      children: [
        for (var index = 0; index < 7; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 6 ? 0 : 5),
              child: _WeekDayButton(
                date: weekStart.add(Duration(days: index)),
                selected: DateUtils.isSameDay(
                  selectedDate,
                  weekStart.add(Duration(days: index)),
                ),
                isToday: DateUtils.isSameDay(
                  today,
                  weekStart.add(Duration(days: index)),
                ),
                count: _occurrencesForDate(
                  occurrences,
                  weekStart.add(Duration(days: index)),
                ).length,
                onTap: () => onSelected(weekStart.add(Duration(days: index))),
              ),
            ),
          ),
      ],
    );
  }
}

class MedicationMonthCalendar extends StatelessWidget {
  const MedicationMonthCalendar({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.occurrences,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<MedicationOccurrence> occurrences;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingDays = firstDay.weekday - 1;
    final cellCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
    final today = DateUtils.dateOnly(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEAF0F4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: _muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final day = index - leadingDays + 1;
              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(month.year, month.month, day);
              final dayOccurrences = _occurrencesForDate(occurrences, date);
              return _MonthDayButton(
                date: date,
                occurrences: dayOccurrences,
                selected: DateUtils.isSameDay(selectedDate, date),
                isToday: DateUtils.isSameDay(today, date),
                onTap: () => onSelected(date),
              );
            },
          ),
          const SizedBox(height: 14),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: [
              _LegendItem(color: Color(0xFF16A34A), label: 'Pris'),
              _LegendItem(color: Color(0xFFF59E0B), label: 'À confirmer'),
              _LegendItem(color: Color(0xFFDC2626), label: 'Ignoré'),
              _LegendItem(color: Color(0xFFCBD5E1), label: 'Aucune prise'),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekDayButton extends StatelessWidget {
  const _WeekDayButton({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.count,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _teal : Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 78),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected || isToday ? _teal : const Color(0xFFEAF0F4),
            width: selected || isToday ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _weekdayLabels[date.weekday - 1],
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _muted,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count prise${count == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 8,
                color: selected ? Colors.white : _teal,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MonthDayButton extends StatelessWidget {
  const _MonthDayButton({
    required this.date,
    required this.occurrences,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final List<MedicationOccurrence> occurrences;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColors = occurrences.isEmpty
        ? const [Color(0xFFCBD5E1)]
        : occurrences
              .map(medicationOccurrenceColor)
              .toSet()
              .toList(growable: false);

    return Material(
      color: selected ? _teal : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected || isToday ? _teal : const Color(0xFFEAF0F4),
              width: selected || isToday ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isToday || selected
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: selected ? Colors.white : _ink,
                ),
              ),
              if (occurrences.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  '${occurrences.length}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _teal,
                  ),
                ),
              ],
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final color in dotColors.take(3))
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: selected && occurrences.isEmpty
                            ? Colors.white70
                            : color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
    ],
  );
}

List<MedicationOccurrence> _occurrencesForDate(
  List<MedicationOccurrence> occurrences,
  DateTime date,
) => occurrences
    .where((occurrence) => DateUtils.isSameDay(occurrence.effectiveDate, date))
    .toList(growable: false);
