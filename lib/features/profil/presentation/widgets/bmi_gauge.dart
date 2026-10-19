import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/user_profile.dart';
import '../../../../i18n/strings.g.dart';

/// Catégories traduites dynamiquement avec slang
extension BmiCategoryLocalized on BmiCategory {
  String get localized => switch (this) {
        BmiCategory.underweight => t.bmiUnderweight,
        BmiCategory.normal => t.bmiNormal,
        BmiCategory.overweight => t.bmiOverweight,
        BmiCategory.obese => t.bmiObesity,
      };
}

/// Couleurs sémantiques de l'IMC (partagées par la jauge et les badges).
extension BmiCategoryColor on BmiCategory {
  Color get color => switch (this) {
        BmiCategory.underweight => const Color(0xFF38BDF8),
        BmiCategory.normal => const Color(0xFF10B981),
        BmiCategory.overweight => const Color(0xFFF59E0B),
        BmiCategory.obese => const Color(0xFFEF4444),
      };
}

/// Jauge semi-circulaire animée et colorée de l'IMC (CustomPainter).
/// Se calcule à partir de la taille / du poids du profil.
class BmiGauge extends StatelessWidget {
  const BmiGauge({super.key, required this.bmi, this.height = 150});

  final double? bmi;
  final double height;

  static const double _min = 12;
  static const double _max = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = bmi;

    if (value == null) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            t.bmiPrompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final category = BmiCategory.fromBmi(value);
    final fraction = ((value - _min) / (_max - _min)).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) {
              final shown = _min + animated * (_max - _min);
              return CustomPaint(
                size: Size.infinite,
                painter: _BmiGaugePainter(
                  fraction: animated,
                  needleColor: theme.colorScheme.onSurface,
                  hubColor: theme.colorScheme.surface,
                ),
                child: Align(
                  alignment: const Alignment(0, 0.55),
                  child: Text(
                    shown.toStringAsFixed(1),
                    style: theme.textTheme.headlineMedium?.copyWith(fontSize: 30, color: category.color),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            category.localized,
            style: TextStyle(color: category.color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _BmiGaugePainter extends CustomPainter {
  _BmiGaugePainter({required this.fraction, required this.needleColor, required this.hubColor});

  final double fraction;
  final Color needleColor;
  final Color hubColor;

  // Bornes des segments OMS : <18.5 | 18.5–25 | 25–30 | ≥30
  static const _bounds = [12.0, 18.5, 25.0, 30.0, 40.0];
  static const _categories = [
    BmiCategory.underweight,
    BmiCategory.normal,
    BmiCategory.overweight,
    BmiCategory.obese,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final radius = (size.width / 2 - stroke).clamp(10.0, size.height - stroke);
    final center = Offset(size.width / 2, size.height - 4);
    final rect = Rect.fromCircle(center: center, radius: radius);

    const total = 40.0 - 12.0;
    const gap = 0.025; // radians
    for (var i = 0; i < _categories.length; i++) {
      final start = math.pi + (_bounds[i] - 12) / total * math.pi;
      final sweep = (_bounds[i + 1] - _bounds[i]) / total * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = _categories[i].color;
      canvas.drawArc(rect, start + gap, sweep - gap * 2, false, paint);
    }

    // Aiguille
    final angle = math.pi + fraction * math.pi;
    final needleLength = radius - stroke * 0.2;
    final tip = Offset(
      center.dx + needleLength * math.cos(angle),
      center.dy + needleLength * math.sin(angle),
    );
    final needle = Paint()
      ..color = needleColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, needle);
    canvas.drawCircle(center, 9, Paint()..color = needleColor);
    canvas.drawCircle(center, 4, Paint()..color = hubColor);
  }


  @override
  bool shouldRepaint(_BmiGaugePainter old) =>
      old.fraction != fraction || old.needleColor != needleColor || old.hubColor != hubColor;
}
