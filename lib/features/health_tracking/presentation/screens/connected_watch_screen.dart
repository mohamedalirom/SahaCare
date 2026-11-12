import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/health_measurement.dart';
import '../controllers/saha_intelligence_controller.dart';
import '../widgets/health_palette.dart';
import '../widgets/phone_frame_insets.dart';
import '../widgets/watch_alert_banner.dart';

/// Écran « Montre connectée » : flux de fréquence cardiaque en direct,
/// comparé à la référence personnelle de l'utilisateur.
/// Deux origines : une vraie montre lue en Bluetooth (capteur cardiaque standard)
/// ou une montre simulée pour la démonstration.
class ConnectedWatchScreen extends ConsumerWidget {
  const ConnectedWatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(connectedWatchProvider);
    final notifier = ref.read(connectedWatchProvider.notifier);
    final color = MeasurementType.heartRate.color;
    final baseline = watch.baseline;

    return PhoneFrameInsets(
      child: Scaffold(
        appBar: AppBar(title: const Text('Montre connectée')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // État de la connexion et valeur en direct
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.healthSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.healthBorder),
              ),
              child: Column(
                children: [
                  // Origine des valeurs : vraie montre (Bluetooth) ou simulation
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<WatchSource>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: WatchSource.real,
                          icon: Icon(Icons.bluetooth_rounded, size: 18),
                          label: Text('Montre réelle'),
                        ),
                        ButtonSegment(
                          value: WatchSource.simulated,
                          icon: Icon(Icons.science_outlined, size: 18),
                          label: Text('Simulation'),
                        ),
                      ],
                      selected: {watch.source},
                      onSelectionChanged: watch.connected || watch.connecting
                          ? null
                          : (selection) => notifier.selectSource(selection.first),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.watch_rounded, color: watch.connected ? color : context.healthTextSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              watch.isReal ? (watch.deviceName ?? 'Capteur cardiaque Bluetooth') : 'SahaWatch (simulation)',
                              style: TextStyle(fontWeight: FontWeight.w600, color: context.healthText),
                            ),
                            Text(
                              watch.connecting
                                  ? 'Recherche du capteur…'
                                  : watch.connected
                                  ? 'Connectée · réception en direct'
                                  : 'Non connectée',
                              style: TextStyle(fontSize: 12, color: context.healthTextSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: watch.connected,
                        onChanged: watch.connecting
                            ? null
                            : (on) {
                                if (!on) {
                                  notifier.disconnect();
                                } else if (watch.isReal) {
                                  notifier.connectReal();
                                } else {
                                  notifier.connect();
                                }
                              },
                      ),
                    ],
                  ),
                  if (watch.error != null) ...[
                    const SizedBox(height: 8),
                    Text(watch.error!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), height: 1.3)),
                  ],
                  if (watch.isReal && !watch.connected && watch.error == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Lancez la diffusion de la fréquence cardiaque sur la montre, activez la connexion, puis '
                      'choisissez le capteur dans la fenêtre du navigateur.',
                      style: TextStyle(fontSize: 12, color: context.healthTextSecondary, height: 1.3),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(Icons.favorite_rounded, color: color, size: 30),
                      const SizedBox(width: 10),
                      Text(
                        watch.current?.round().toString() ?? '--',
                        style: TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: context.healthText, height: 1),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('bpm', style: TextStyle(fontSize: 16, color: context.healthTextSecondary)),
                      ),
                    ],
                  ),
                  if (baseline != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Votre plage habituelle : ${baseline.low.round()} – ${baseline.high.round()} bpm',
                      style: TextStyle(fontSize: 12, color: context.healthTextSecondary),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(height: 150, child: _LiveChart(watch: watch, color: color)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (watch.alert != null) ...[
              WatchAlertBanner(alert: watch.alert!, onDismiss: notifier.dismissAlert),
              const SizedBox(height: 14),
            ],

            if (!watch.isReal) ...[
              FilledButton.tonalIcon(
                onPressed: watch.connected ? notifier.simulateSpike : null,
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Simuler un pic de fréquence cardiaque'),
              ),
              const SizedBox(height: 14),
            ],

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.healthSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.healthBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comment ça marche',
                    style: TextStyle(fontWeight: FontWeight.w600, color: context.healthText),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chaque valeur reçue est comparée à votre moyenne personnelle des 90 derniers jours. '
                    'Deux valeurs inhabituelles de suite déclenchent une alerte et sont gardées dans votre historique.',
                    style: TextStyle(fontSize: 12.5, color: context.healthTextSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${watch.savedCount} mesure(s) de cette session enregistrée(s) dans votre historique.',
                    style: TextStyle(fontSize: 12.5, color: context.healthText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveChart extends StatelessWidget {
  final WatchState watch;
  final Color color;

  const _LiveChart({required this.watch, required this.color});

  @override
  Widget build(BuildContext context) {
    final baseline = watch.baseline!;
    final readings = watch.readings;
    var minY = baseline.low - 10;
    var maxY = baseline.high + 10;
    for (final v in readings) {
      if (v - 5 < minY) minY = v - 5;
      if (v + 5 > maxY) maxY = v + 5;
    }

    return LineChart(
      duration: Duration.zero,
      LineChartData(
        minX: 0,
        maxX: (ConnectedWatchNotifier.maxReadings - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        // Bande verte : plage habituelle de l'utilisateur
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            HorizontalRangeAnnotation(
              y1: baseline.low,
              y2: baseline.high,
              color: const Color(0xFF059669).withValues(alpha: 0.12),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (int i = 0; i < readings.length; i++) FlSpot(i.toDouble(), readings[i])],
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
