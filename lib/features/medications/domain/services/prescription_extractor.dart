import '../entities/prescription_scan.dart';
import '../entities/medication_suggestion.dart';
import '../entities/medication_text_normalizer.dart';
import 'prescription_catalog_matcher.dart';

/// Conservative lexical suggestions, never a prescription or an automatic save.
class PrescriptionExtractor {
  String _normalize(String text) =>
      normalizeMedicationText(text)
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
  List<PrescriptionCandidate> extract(
    String raw,
    List<MedicationSuggestion> catalog, {
    bool allowExplicitFields = true,
  }) {
    if (raw.length > 30000) {
      throw ArgumentError(
        'Le texte dépasse 30 000 caractères. Réduisez la zone analysée.',
      );
    }
    final lines = raw.split(RegExp(r'\r?\n'));
    final results = <PrescriptionCandidate>[];
    final seen = <String>{};
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.isEmpty) continue;
      final evidence = PrescriptionCatalogMatcher().match(line, catalog);
      final exact = evidence
          .where((m) => m.level == PrescriptionMatchLevel.exact)
          .map((m) => m.medication)
          .toList();
      final candidates = evidence.map((m) => m.medication).toList();
      if (candidates.isEmpty) continue;
      // Only consume a continuation when it is explicitly about dose/time/duration.
      var context = line;
      if (candidates.length == 1 && index + 1 < lines.length) {
        final next = lines[index + 1].trim();
        final n = _normalize(next);
        final another = catalog.any(
          (m) => (' $n ').contains(' ${_normalize(m.name)} '),
        );
        if (!another &&
            RegExp(
              r'^(?:\d+\s*(?:comprime|gelule|ml|goutte)|pendant\b|a\s+\d|matin\b|soir\b|posologie\b)',
              caseSensitive: false,
            ).hasMatch(n)) {
          context = '$line\n$next';
        }
      }
      final unambiguous =
          allowExplicitFields && candidates.length == 1 && exact.isNotEmpty;
      final strengths = RegExp(
        r'\b\d+(?:[.,]\d+)?\s*(?:mg|mcg|µg|g|mL|ml|UI)(?:\s*/\s*\d*(?:[.,]\d+)?\s*(?:mg|g|mL|ml))?\b',
        caseSensitive: false,
      ).allMatches(context).map((m) => m.group(0)!).toSet();
      final duration = RegExp(
        r'\b(?:pendant|duree\s*:?)\s+(\d{1,3})\s*(?:jours?|j)\b',
      ).firstMatch(normalizeMedicationText(context));
      final frequency = RegExp(
        r'\b[1-6]\s*(?:fois|x)\s*(?:par\s+jour|/\s*jour)\b',
        caseSensitive: false,
      ).firstMatch(context)?.group(0);
      final dates = RegExp(
        r'\bdu\s+(\d{2}/\d{2}/\d{4})\s+au\s+(\d{2}/\d{2}/\d{4})\b',
        caseSensitive: false,
      ).firstMatch(context);
      final groups = exact.length > 1
          ? exact.map((m) => [m]).toList()
          : [candidates];
      for (final group in groups) {
        final nameKey = _normalize(group.first.name);
        final strength = unambiguous && strengths.length == 1
            ? strengths.single
            : null;
        final duplicateKey = '$nameKey|${strength ?? ''}';
        results.add(
          PrescriptionCandidate(
            key: 'line-$index-$nameKey',
            line: index + 1,
            sourceText: context,
            matches: List.unmodifiable(group),
            exactName: exact.isNotEmpty,
            lineAmbiguous: exact.length > 1,
            lowQuality: !allowExplicitFields,
            evidence: evidence
                .where((m) => group.contains(m.medication))
                .toList(),
            strength: strength,
            frequency: unambiguous ? frequency : null,
            durationDays:
                unambiguous &&
                    duration != null &&
                    int.parse(duration.group(1)!) > 0
                ? int.tryParse(duration.group(1)!)
                : null,
            times: unambiguous ? _times(context) : const [],
            daily:
                unambiguous &&
                RegExp(r'\b(?:tous les jours|quotidien(?:nement)?)\b')
                    .hasMatch(normalizeMedicationText(context)),
            startDate: unambiguous && dates != null
                ? _date(dates.group(1)!)
                : null,
            endDate: unambiguous && dates != null
                ? _date(dates.group(2)!)
                : null,
            repeated: !seen.add(duplicateKey),
          ),
        );
        if (results.length >= 40) break;
      }
      if (results.length >= 40) break;
    }
    return results;
  }

  DateTime? _date(String value) {
    final p = value.split('/').map(int.parse).toList();
    final date = DateTime(p[2], p[1], p[0]);
    return date.year == p[2] && date.month == p[1] && date.day == p[0]
        ? date
        : null;
  }

  List<String> _times(String text) {
    final times = <String>{};
    for (final match in RegExp(
      r'\b([01]?\d|2[0-3])(?::([0-5]\d)|h([0-5]\d)?)\b',
      caseSensitive: false,
    ).allMatches(text)) {
      final prefix = normalizeMedicationText(text.substring(0, match.start));
      if (RegExp(r'(?:toutes?\s+les?|chaque|pendant|duree\s*:?|durant)\s*$')
          .hasMatch(prefix)) {
        continue;
      }
      if (match.group(2) == null &&
          match.group(3) == null &&
          !RegExp(r'(?:\ba|\bvers|\bet|[,;])\s*$').hasMatch(prefix)) {
        continue;
      }
      times.add(
        '${match.group(1)!.padLeft(2, '0')}:${match.group(2) ?? match.group(3) ?? '00'}',
      );
    }
    return times.toList()..sort();
  }
}
