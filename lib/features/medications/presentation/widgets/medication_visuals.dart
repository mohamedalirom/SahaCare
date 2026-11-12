import 'package:flutter/material.dart';

/// Presentation-only components shared by the medication screens.
class MedicationColors {
  static const teal = Color(0xFF0D9488);
  static const ink = Color(0xFF153D42);
  static const muted = Color(0xFF647D83);
  static const canvas = Color(0xFFF3F8F8);
  static const mint = Color(0xFFE4F7F1);
  static const line = Color(0xFFE3EEEE);
}

class MedicationSurface extends StatelessWidget {
  const MedicationSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gradient,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      gradient: gradient,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: MedicationColors.line),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF174B4B).withValues(alpha: .035),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

class MedicationBadge extends StatelessWidget {
  const MedicationBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Small vector illustration: decoration only, never a medication presentation.
class MedicationIllustration extends StatelessWidget {
  const MedicationIllustration({super.key, this.size = 76});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PillsPainter()),
    ),
  );
}

class _PillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawCircle(
      const Offset(50, 50),
      45,
      Paint()..color = const Color(0xFFDDF2EE),
    );
    canvas.drawCircle(
      const Offset(80, 20),
      9,
      Paint()..color = const Color(0xFFDBEAF9),
    );
    canvas.save();
    canvas.translate(47, 45);
    canvas.rotate(-.6);
    final capsule = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-17, -30, 34, 60),
      const Radius.circular(17),
    );
    canvas.drawRRect(
      capsule.shift(const Offset(3, 5)),
      Paint()..color = MedicationColors.teal.withValues(alpha: .12),
    );
    canvas.drawRRect(capsule, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(capsule);
    canvas.drawRect(
      const Rect.fromLTWH(-17, -30, 34, 30),
      Paint()..color = const Color(0xFF50BBAE),
    );
    canvas.restore();
    canvas.drawLine(
      const Offset(-10, -19),
      const Offset(-10, -8),
      Paint()
        ..color = Colors.white.withValues(alpha: .7)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    canvas.drawCircle(
      const Offset(71, 72),
      17,
      Paint()..color = const Color(0xFFBCDCEC),
    );
    canvas.drawCircle(
      const Offset(69, 69),
      17,
      Paint()..color = const Color(0xFFEAF4FD),
    );
    canvas.drawLine(
      const Offset(61, 76),
      const Offset(77, 62),
      Paint()
        ..color = const Color(0xFFABCADA)
        ..strokeWidth = 2,
    );
    final cross = Paint()
      ..color = MedicationColors.teal.withValues(alpha: .6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(15, 70), const Offset(15, 82), cross);
    canvas.drawLine(const Offset(9, 76), const Offset(21, 76), cross);
  }

  @override
  bool shouldRepaint(covariant _PillsPainter oldDelegate) => false;
}
