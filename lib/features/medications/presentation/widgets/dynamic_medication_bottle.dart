import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/medication_stock.dart';
import 'medication_visuals.dart';

/// A symbolic reserve, never a claim about physical packaging capacity.
class DynamicMedicationBottle extends StatelessWidget {
  const DynamicMedicationBottle({
    super.key,
    required this.currentQuantity,
    required this.referenceQuantity,
    required this.unit,
    required this.lowThreshold,
    required this.enabled,
    this.color = MedicationColors.teal,
    this.height = 210,
  });
  final StockQuantity currentQuantity;
  final StockQuantity referenceQuantity;
  final StockUnit unit;
  final StockQuantity lowThreshold;
  final bool enabled;
  final Color color;
  final double height;

  double get fillFraction {
    final scale = math.max(
      referenceQuantity.milliUnits,
      currentQuantity.milliUnits,
    );
    return !enabled || scale <= 0
        ? 0
        : (currentQuantity.milliUnits / scale).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: enabled
        ? 'Réserve symbolique : ${currentQuantity.display} ${unit.label}. Seuil d’alerte : ${lowThreshold.display} ${unit.label}.'
        : 'Suivi du stock désactivé. Niveau non représenté.',
    image: true,
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          height: height,
          width: height * .8,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: fillFraction, end: fillFraction),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (_, level, _) => CustomPaint(
              painter: MedicationBottlePainter(
                level: level,
                unit: unit,
                enabled: enabled,
                color: color,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class MedicationBottlePainter extends CustomPainter {
  const MedicationBottlePainter({
    required this.level,
    required this.unit,
    required this.enabled,
    required this.color,
  });
  final double level;
  final StockUnit unit;
  final bool enabled;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 180, size.height / 225);
    final shadow = Paint()
      ..color = MedicationColors.ink.withValues(alpha: .10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(const Rect.fromLTWH(25, 205, 130, 12), shadow);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(27, 43, 126, 161),
      const Radius.circular(26),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            MedicationColors.mint.withValues(alpha: .65),
            Colors.white,
          ],
          stops: const [0, .6, 1],
        ).createShader(body.outerRect),
    );
    canvas.save();
    canvas.clipRRect(body.deflate(5));
    final fill = Rect.fromLTRB(32, 199 - 143 * level, 148, 199);
    if (enabled && level > 0) {
      canvas.drawRect(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: .08),
              color.withValues(alpha: .25),
            ],
          ).createShader(fill),
      );
      final solid = unit == StockUnit.capsule || unit == StockUnit.tablet;
      if (solid) {
        canvas.clipRect(fill);
        // A bounded symbolic pattern, not one painted pill per inventory unit.
        for (var row = 0; row < 6; row++) {
          for (var col = 0; col < 3; col++) {
            canvas.save();
            canvas.translate(
              48 + col * 34.0 + (row.isOdd ? 3 : 0),
              184 - row * 24.0,
            );
            canvas.rotate((row + col).isEven ? -.35 : .3);
            final capsule = RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: unit == StockUnit.tablet ? 20 : 27,
                height: 13,
              ),
              const Radius.circular(8),
            );
            canvas.drawRRect(capsule, Paint()..color = Colors.white);
            canvas.save();
            canvas.clipRRect(capsule);
            canvas.drawRect(
              const Rect.fromLTWH(-15, -8, 15, 16),
              Paint()..color = color.withValues(alpha: .85),
            );
            canvas.restore();
            canvas.drawRRect(
              capsule,
              Paint()
                ..color = color.withValues(alpha: .35)
                ..style = PaintingStyle.stroke
                ..strokeWidth = .8,
            );
            canvas.restore();
          }
        }
      }
    }
    canvas.restore();
    canvas.drawRRect(
      body,
      Paint()
        ..color = MedicationColors.teal.withValues(alpha: .28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(36, 64, 7, 110),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: .7),
    );
    final cap = RRect.fromRectAndRadius(
      const Rect.fromLTWH(39, 17, 102, 37),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      cap,
      Paint()
        ..shader = const LinearGradient(
          colors: [MedicationColors.teal, MedicationColors.ink],
        ).createShader(cap.outerRect),
    );
    for (var x = 48.0; x < 136; x += 9) {
      canvas.drawLine(
        Offset(x, 25),
        Offset(x, 44),
        Paint()
          ..color = Colors.white.withValues(alpha: .18)
          ..strokeWidth = 2,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(49, 15, 82, 5),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withValues(alpha: .4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MedicationBottlePainter oldDelegate) =>
      level != oldDelegate.level ||
      unit != oldDelegate.unit ||
      enabled != oldDelegate.enabled ||
      color != oldDelegate.color;
}
