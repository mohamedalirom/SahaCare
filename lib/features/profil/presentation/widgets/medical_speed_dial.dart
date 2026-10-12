import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../i18n/strings.g.dart';
import 'add_medical_record_sheet.dart';

/// Animated speed-dial FAB. Expanded state lives in [open] so the host screen
/// can render a scrim behind it and close it on outside taps.
class MedicalSpeedDial extends StatefulWidget {
  const MedicalSpeedDial({super.key, required this.open, required this.onSelected});

  final ValueNotifier<bool> open;
  final ValueChanged<MedicalRecordType> onSelected;

  @override
  State<MedicalSpeedDial> createState() => _MedicalSpeedDialState();
}

class _MedicalSpeedDialState extends State<MedicalSpeedDial> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    widget.open.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(covariant MedicalSpeedDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open != widget.open) {
      oldWidget.open.removeListener(_sync);
      widget.open.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.open.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    if (widget.open.value) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    widget.open.value = !widget.open.value;
  }

  @override
  Widget build(BuildContext context) {
    final types = MedicalRecordType.values.reversed.toList(); // closest to FAB last
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < types.length; i++)
          _DialAction(
            type: types[i],
            animation: CurvedAnimation(
              parent: _controller,
              curve: Interval(0.1 * i, 0.7 + 0.1 * i, curve: Curves.easeOutBack),
            ),
            onTap: () {
              widget.open.value = false;
              widget.onSelected(types[i]);
            },
          ),
        FloatingActionButton(
          heroTag: 'medical_speed_dial',
          tooltip: t.add,
          onPressed: _toggle,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, child) => Transform.rotate(angle: _controller.value * 0.785398, child: child),
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ],
    );
  }
}

class _DialAction extends StatelessWidget {
  const _DialAction({required this.type, required this.animation, required this.onTap});

  final MedicalRecordType type;
  final Animation<double> animation;
  final VoidCallback onTap;

  String _labelFor(MedicalRecordType type) => switch (type) {
        MedicalRecordType.disease => t.addCondition,
        MedicalRecordType.allergy => t.addAllergy,
        MedicalRecordType.history => t.addHistory,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final v = animation.value.clamp(0.0, 1.0);
        return IgnorePointer(
          ignoring: v < 0.5,
          child: Opacity(
            opacity: v,
            child: Transform.translate(offset: Offset(0, (1 - v) * 24), child: child),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(10),
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(_labelFor(type), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                elevation: 3,
                shape: const CircleBorder(),
                color: type.color,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(type.icon, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
