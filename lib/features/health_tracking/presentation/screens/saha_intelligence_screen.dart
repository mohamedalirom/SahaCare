import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/health_insight.dart';
import '../../domain/entities/health_measurement.dart';
import '../../domain/services/health_analysis_engine.dart';
import '../controllers/saha_intelligence_controller.dart';
import '../widgets/health_async_view.dart';
import '../widgets/health_palette.dart';
import '../widgets/phone_frame_insets.dart';

/// Écran « Saha Intelligence » : analyse des mesures, résumé rédigé par un
/// modèle Hugging Face et questions à l'assistant.
class SahaIntelligenceScreen extends ConsumerWidget {
  const SahaIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PhoneFrameInsets(
      child: Scaffold(
        appBar: AppBar(title: const Text('Saha Intelligence')),
        body: HealthAsyncView(
          builder: (_) {
            final analysis = ref.watch(healthAnalysisProvider);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const _ReportCard(),
                const SizedBox(height: 20),
                Text(
                  'Analyse de vos mesures',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.healthText),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chaque valeur est comparée à vos propres habitudes des 90 derniers jours.',
                  style: TextStyle(fontSize: 12, color: context.healthTextSecondary),
                ),
                const SizedBox(height: 10),
                if (analysis == null || analysis.isEmpty)
                  const EmptyMeasurementsMessage(message: 'Pas encore assez de mesures à analyser.')
                else
                  ...analysis.insights.map((i) => _InsightCard(insight: i)),
                const SizedBox(height: 12),
                const _AssistantSection(),
                const SizedBox(height: 16),
                const Text(
                  'ℹ️ Saha Intelligence décrit vos mesures. Il ne pose pas de diagnostic et ne remplace pas '
                  'l\'avis d\'un médecin.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// Résumé de la semaine
// ============================================================================

class _ReportCard extends ConsumerWidget {
  const _ReportCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final report = ref.watch(weeklyReportProvider);
    final value = report.value;
    final loading = report.isLoading;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Résumé de la semaine',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              IconButton(
                tooltip: 'Générer à nouveau',
                visualDensity: VisualDensity.compact,
                onPressed: loading ? null : () => ref.read(weeklyReportProvider.notifier).regenerate(),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ref.watch(llmStatusProvider).value ?? 'Rédaction du résumé…',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else if (value != null) ...[
            Text(value.text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
            const SizedBox(height: 14),
            _SourceChip(
              icon: value.fromAi ? Icons.smart_toy_outlined : Icons.calculate_outlined,
              label: value.fromAi ? 'Rédigé par ${value.model} · Hugging Face' : 'Résumé calculé sur l\'appareil',
            ),
            if (value.onDevice) ...[
              const SizedBox(height: 6),
              const Text(
                'Le modèle tourne dans votre navigateur : vos mesures ne quittent pas l\'appareil.',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
            if (!value.fromAi && value.fallbackReason != null) ...[
              const SizedBox(height: 6),
              Text(value.fallbackReason!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ] else
            const Text('Résumé indisponible.', style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SourceChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Carte d'analyse d'un indicateur
// ============================================================================

class _InsightCard extends StatelessWidget {
  final MetricInsight insight;

  const _InsightCard({required this.insight});

  static const Color _warning = Color(0xFFD97706);
  static const Color _ok = Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    final type = insight.type;
    final unit = type.unit;
    String fmt(double v) => HealthAnalysisEngine.formatValue(v, type);

    final (IconData trendIcon, String trendText) = switch (insight.trend) {
      TrendDirection.up => (
        Icons.trending_up_rounded,
        'En hausse · +${insight.slopePerWeek!.abs().toStringAsFixed(type.decimals + 1).replaceAll('.', ',')} $unit / semaine',
      ),
      TrendDirection.down => (
        Icons.trending_down_rounded,
        'En baisse · -${insight.slopePerWeek!.abs().toStringAsFixed(type.decimals + 1).replaceAll('.', ',')} $unit / semaine',
      ),
      TrendDirection.stable => (Icons.trending_flat_rounded, 'Stable sur 30 jours'),
      TrendDirection.unknown => (Icons.more_horiz_rounded, 'Tendance : pas assez de mesures'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.healthSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: insight.isUnusual ? _warning : context.healthBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(type.icon, color: type.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  insight.label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.healthText),
                ),
              ),
              Text(
                '${insight.latest.displayValue.replaceAll('.', ',')} $unit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.healthText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (insight.hasBaseline) ...[
            _Line(
              icon: insight.isUnusual ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: insight.isUnusual ? _warning : _ok,
              text: insight.isUnusual
                  ? 'Inhabituel pour vous (${insight.zScore! > 0 ? 'plus haut' : 'plus bas'} que d\'habitude)'
                  : 'Dans votre plage habituelle',
            ),
            _Line(
              icon: Icons.person_outline_rounded,
              text:
                  'Votre moyenne : ${fmt(insight.baselineMean!)} $unit '
                  '(± ${insight.baselineStdDev!.toStringAsFixed(1).replaceAll('.', ',')})',
            ),
          ] else
            const _Line(icon: Icons.person_outline_rounded, text: 'Référence personnelle : pas assez de mesures'),
          _Line(icon: trendIcon, text: trendText),
          if (insight.trend == TrendDirection.up || insight.trend == TrendDirection.down)
            _Line(
              icon: Icons.flag_outlined,
              text: 'Projection dans 30 jours : environ ${fmt(insight.projected30d!)} $unit',
            ),
          if (insight.recentOutliers.isNotEmpty)
            _Line(
              icon: Icons.report_gmailerrorred_rounded,
              color: _warning,
              text:
                  'Valeurs inhabituelles sur 30 jours : '
                  '${insight.recentOutliers.map((m) => '${m.displayValue.replaceAll('.', ',')} (${HealthAnalysisEngine.formatDate(m.dateTime)})').join(', ')}',
            ),
          _Line(
            icon: Icons.event_available_outlined,
            text: '${insight.last7Days} mesure(s) cette semaine · ${insight.previous7Days} la semaine précédente',
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _Line({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.healthTextSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: c, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Questions à l'assistant
// ============================================================================

class _AssistantSection extends ConsumerStatefulWidget {
  const _AssistantSection();

  @override
  ConsumerState<_AssistantSection> createState() => _AssistantSectionState();
}

class _AssistantSectionState extends ConsumerState<_AssistantSection> {
  final _controller = TextEditingController();

  static const _suggestions = [
    'Comment évolue ma tension ce mois-ci ?',
    'Mon poids est-il stable ?',
    'Ai-je été régulier cette semaine ?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final question = text ?? _controller.text;
    if (question.trim().isEmpty) return;
    _controller.clear();
    ref.read(assistantChatProvider.notifier).ask(question);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(assistantChatProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.healthSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.healthBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum_outlined, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Poser une question sur mes mesures',
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.healthText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (chat.entries.isEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    onPressed: chat.sending ? null : () => _send(s),
                  ),
              ],
            ),
          for (final entry in chat.entries) _Bubble(entry: entry),
          if (chat.sending)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                ref.watch(llmStatusProvider).value ?? 'L\'assistant rédige sa réponse…',
                style: TextStyle(fontSize: 12, color: context.healthTextSecondary),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !chat.sending,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Votre question…', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Envoyer',
                onPressed: chat.sending ? null : _send,
                icon: const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatEntry entry;

  const _Bubble({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = entry.fromUser
        ? theme.colorScheme.primary
        : entry.isError
        ? const Color(0xFFDC2626).withValues(alpha: 0.10)
        : theme.colorScheme.primary.withValues(alpha: 0.08);
    final foreground = entry.fromUser
        ? Colors.white
        : entry.isError
        ? const Color(0xFFDC2626)
        : context.healthText;

    return Align(
      alignment: entry.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 290),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
        child: Text(entry.text, style: TextStyle(fontSize: 13, color: foreground, height: 1.4)),
      ),
    );
  }
}
