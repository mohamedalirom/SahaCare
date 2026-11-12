import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_stock.dart';
import '../../domain/entities/medication_text_normalizer.dart';

// Exact colors already used by the medication dashboard. No global theme edits.
class DashboardPalette {
  static const teal = Color(0xFF0D9488);
  static const deepTeal = Color(0xFF0F766E);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const mint = Color(0xFFCCFBF1);
  static const line = Color(0xFFE2E8F0);
  static const canvas = Color(0xFFF8FAFC);
}

class DashboardMedicalArt extends StatelessWidget {
  const DashboardMedicalArt({super.key, this.size = 80, this.dark = false});
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * .9,
              height: size * .9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark
                    ? Colors.white.withValues(alpha: .06)
                    : DashboardPalette.mint,
              ),
            ),
            Transform.rotate(
              angle: -.55,
              child: Container(
                width: size * .34,
                height: size * .67,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size),
                  boxShadow: [
                    BoxShadow(
                      color: DashboardPalette.teal.withValues(alpha: .2),
                      blurRadius: 16,
                      offset: const Offset(2, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(size),
                  child: Column(
                    children: [
                      Expanded(
                        child: ColoredBox(
                          color: Colors.white,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: DashboardPalette.teal,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: size * .08,
              child: Container(
                padding: EdgeInsets.all(size * .075),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: DashboardPalette.teal,
                  size: size * .23,
                ),
              ),
            ),
            Positioned(
              left: size * .05,
              top: size * .1,
              child: Icon(
                Icons.auto_awesome_outlined,
                size: size * .16,
                color: dark ? Colors.white : DashboardPalette.teal,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DashboardHero extends StatelessWidget {
  const DashboardHero({super.key});
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 6),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: DashboardPalette.ink,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: DashboardPalette.ink.withValues(alpha: .12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final art =
                box.maxWidth > 280 &&
                MediaQuery.textScalerOf(context).scale(14) < 21;
            final artSize = box.maxWidth >= 320 ? 88.0 : 80.0;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: DashboardPalette.mint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'VOTRE ESPACE SANTÉ',
                              style: TextStyle(
                                color: DashboardPalette.mint,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Mes traitements',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                          height: 1.08,
                          letterSpacing: -.9,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Vos médicaments,\nvotre rythme au quotidien.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (art) ...[
                  const SizedBox(width: 14),
                  DashboardMedicalArt(size: artSize, dark: true),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class DashboardOverview extends StatelessWidget {
  const DashboardOverview({
    super.key,
    required this.activeCount,
    required this.doseCount,
  });
  final int activeCount;
  final int doseCount;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final stacked = MediaQuery.textScalerOf(context).scale(14) > 21;
      Widget metric(
        int value,
        String label,
        IconData icon,
        String key,
        bool accent,
      ) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accent ? DashboardPalette.mint : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: accent ? DashboardPalette.mint : DashboardPalette.line,
          ),
          boxShadow: [
            BoxShadow(
              color: DashboardPalette.ink.withValues(alpha: .06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$value',
                    key: ValueKey(key),
                    style: const TextStyle(
                      color: DashboardPalette.ink,
                      fontSize: 35,
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
                Icon(icon, size: 20, color: DashboardPalette.deepTeal),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              label,
              style: const TextStyle(
                color: DashboardPalette.ink,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
      final first = metric(
        activeCount,
        'Traitements actifs',
        Icons.medication_outlined,
        'active-treatment-count',
        false,
      );
      final second = metric(
        doseCount,
        'Prises prévues aujourd’hui',
        Icons.schedule_rounded,
        'planned-dose-count',
        true,
      );
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 10), second],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        ),
      );
    },
  );
}

class DashboardTool {
  const DashboardTool({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class DashboardToolGrid extends StatelessWidget {
  const DashboardToolGrid({super.key, required this.tools});
  final List<DashboardTool> tools;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns =
          box.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(14) <= 21
          ? 2
          : 1;
      return Column(
        children: [
          for (var i = 0; i < tools.length; i += columns)
            Padding(
              padding: EdgeInsets.only(
                bottom: i + columns < tools.length ? 10 : 0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var j = i;
                      j < math.min(i + columns, tools.length);
                      j++
                    ) ...[
                      if (j != i) const SizedBox(width: 10),
                      Expanded(child: _ToolTile(tool: tools[j])),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});
  final DashboardTool tool;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: tool.onTap,
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? DashboardPalette.teal.withValues(alpha: .06)
            : null,
      ),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: DashboardPalette.line),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DashboardPalette.canvas,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tool.icon,
                    size: 22,
                    color: DashboardPalette.teal,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.north_east_rounded,
                  size: 16,
                  color: DashboardPalette.muted,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              tool.title,
              style: const TextStyle(
                color: DashboardPalette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              tool.subtitle,
              style: const TextStyle(
                color: DashboardPalette.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DashboardScannerBanner extends StatelessWidget {
  const DashboardScannerBanner({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: DashboardPalette.mint,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.document_scanner_outlined,
                color: DashboardPalette.deepTeal,
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scanner une ordonnance',
                    style: TextStyle(
                      color: DashboardPalette.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Lire, vérifier, puis ajouter.',
                    style: TextStyle(
                      color: DashboardPalette.deepTeal,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              color: DashboardPalette.deepTeal,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

class DashboardEmptyState extends StatelessWidget {
  const DashboardEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.onAdd,
  });
  final String title;
  final String description;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: DashboardPalette.line),
    ),
    child: Column(
      children: [
        const DashboardMedicalArt(size: 74),
        const SizedBox(height: 13),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: DashboardPalette.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: DashboardPalette.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        if (onAdd != null) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Mon premier traitement'),
            style: TextButton.styleFrom(foregroundColor: DashboardPalette.teal),
          ),
        ],
      ],
    ),
  );
}

/// Flags only explicit tablet/capsule contradictions, without converting units.
bool hasDashboardStockPresentationMismatch(Medication medication) {
  final stock = medication.stock;
  if (stock == null || !stock.enabled) return false;
  final presentation = normalizeMedicationText(
    medication.commercialPresentation ?? '',
  );
  final tablet = RegExp(r'\bcomprimes?\b').hasMatch(presentation);
  final capsule = RegExp(r'\b(gelules?|capsules?)\b').hasMatch(presentation);
  if (tablet == capsule) return false;
  return (tablet && stock.unit == StockUnit.capsule) ||
      (capsule && stock.unit == StockUnit.tablet);
}

class DashboardMedicationCard extends StatelessWidget {
  const DashboardMedicationCard({
    super.key,
    required this.medication,
    required this.onTap,
    this.onReviewStock,
  });
  final Medication medication;
  final VoidCallback onTap;
  final VoidCallback? onReviewStock;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final ended =
        medication.endDate != null &&
        today.isAfter(DateUtils.dateOnly(medication.endDate!));
    final upcoming = today.isBefore(DateUtils.dateOnly(medication.startDate));
    final status = ended
        ? 'Terminé'
        : upcoming
        ? 'À venir'
        : 'Actif';
    final stock = medication.stock;
    return Material(
      color: Colors.white,
      elevation: .6,
      shadowColor: DashboardPalette.ink.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: DashboardPalette.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DashboardPalette.mint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.medication_outlined,
                      color: DashboardPalette.teal,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          style: const TextStyle(
                            color: DashboardPalette.ink,
                            fontSize: 17,
                            letterSpacing: -.2,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ended
                                ? DashboardPalette.canvas
                                : DashboardPalette.mint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: ended
                                  ? DashboardPalette.muted
                                  : DashboardPalette.deepTeal,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${medication.dosage} • ${(medication.scheduleTimes.isEmpty ? [medication.time] : medication.scheduleTimes).join(' • ')}',
                style: const TextStyle(
                  color: DashboardPalette.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              if (medication.activeIngredient case final ingredient?) ...[
                const SizedBox(height: 7),
                Text(
                  'Substance active : $ingredient',
                  style: const TextStyle(
                    color: DashboardPalette.muted,
                    fontSize: 12,
                  ),
                ),
              ],
              if (medication.commercialPresentation
                  case final presentation?) ...[
                const SizedBox(height: 4),
                Text(
                  'Présentation : $presentation',
                  style: const TextStyle(
                    color: DashboardPalette.muted,
                    fontSize: 12,
                  ),
                ),
              ],
              if (stock != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DashboardPalette.canvas,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: DashboardPalette.teal,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          !stock.enabled
                              ? 'Suivi du stock désactivé'
                              : stock.pendingAnomalies > 0
                              ? 'Stock à régulariser : ${stock.pendingAnomalies} anomalie(s)'
                              : 'Stock : ${stock.remaining.display} ${stock.unit.label}'
                                    '${stock.alert == StockAlert.low || stock.alert == StockAlert.empty ? ' • Stock faible' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color:
                                stock.alert == StockAlert.anomaly ||
                                    stock.alert == StockAlert.empty
                                ? const Color(0xFFDC2626)
                                : stock.alert == StockAlert.low
                                ? const Color(0xFFD97706)
                                : DashboardPalette.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (hasDashboardStockPresentationMismatch(medication)) ...[
                const SizedBox(height: 10),
                Text(
                  'Présentation et unité à vérifier : le stock est enregistré en ${stock!.unit.label}. Aucune correction automatique.',
                  key: ValueKey('stock-presentation-warning-${medication.id}'),
                  style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                TextButton.icon(
                  onPressed: onReviewStock ?? onTap,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Vérifier la présentation et le stock'),
                  style: TextButton.styleFrom(
                    foregroundColor: DashboardPalette.deepTeal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Timeline of the existing planned times, not an invented occurrence history.
class DashboardDoseTile extends StatelessWidget {
  const DashboardDoseTile({
    super.key,
    required this.medication,
    required this.time,
    required this.onTap,
  });
  final Medication medication;
  final String time;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 5,
        top: 0,
        bottom: 0,
        child: Container(width: 2, color: DashboardPalette.line),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 22),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: DashboardPalette.line),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HORAIRE PRÉVU',
                    style: TextStyle(
                      color: DashboardPalette.deepTeal,
                      fontSize: 10,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '$time • ${medication.name}',
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: DashboardPalette.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          medication.dosage,
                          style: const TextStyle(
                            color: DashboardPalette.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (medication.reminderEnabled)
                        const Tooltip(
                          message: 'Rappel activé',
                          child: Icon(
                            Icons.notifications_active_outlined,
                            color: DashboardPalette.teal,
                            size: 18,
                          ),
                        ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: DashboardPalette.muted,
                        size: 17,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: 0,
        top: 24,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: DashboardPalette.teal,
            shape: BoxShape.circle,
            border: Border.all(color: DashboardPalette.mint, width: 3),
          ),
        ),
      ),
    ],
  );
}
