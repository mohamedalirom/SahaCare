import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Réserve l'espace de l'encoche et de la barre d'accueil dessinées par
/// [PhoneFrameWrapper] (core/widgets), qui ne les déclare pas dans MediaQuery.
/// Sans cela, les titres de l'AppBar passent sous l'encoche.
/// Sur un vrai téléphone (ou une fenêtre étroite), rien ne change.
class PhoneFrameInsets extends StatelessWidget {
  final Widget child;

  /// Même seuil que PhoneFrameWrapper : au-delà, l'app est affichée dans le cadre
  static const double _frameMinWidth = 550;
  static const double _notchHeight = 40;
  static const double _homeIndicatorHeight = 16;

  const PhoneFrameInsets({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < _frameMinWidth) return child;
    final padding = mq.padding.copyWith(
      top: math.max(mq.padding.top, _notchHeight),
      bottom: math.max(mq.padding.bottom, _homeIndicatorHeight),
    );
    return MediaQuery(
      data: mq.copyWith(padding: padding, viewPadding: padding),
      child: child,
    );
  }
}
