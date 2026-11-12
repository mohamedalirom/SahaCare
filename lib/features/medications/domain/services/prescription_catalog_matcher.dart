import '../entities/medication_suggestion.dart';
import '../entities/medication_text_normalizer.dart';
import '../entities/prescription_scan.dart';

/// Lexical retrieval only: no clinical equivalence or probability of correctness.
class PrescriptionCatalogMatcher {
  String normalize(String text) =>
      normalizeMedicationText(text)
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
  String _confusions(String text) => text
      .replaceAll('0', 'o')
      .replaceAll('1', 'l')
      .replaceAllMapped(RegExp(r'([a-z])q'), (m) => '${m[1]}g');

  List<PrescriptionCatalogMatch> match(
    String line,
    List<MedicationSuggestion> catalog,
  ) {
    final text = normalize(line);
    bool contains(String value) =>
        value.isNotEmpty && (' $text ').contains(' $value ');
    final exact = catalog.where((m) => contains(normalize(m.name))).toList();
    if (exact.isNotEmpty) {
      return exact
          .map((m) => PrescriptionCatalogMatch(m, PrescriptionMatchLevel.exact))
          .toList();
    }
    final aliases = catalog
        .where(
          (m) => [
            m.activeIngredient ?? '',
            ...m.searchTerms,
          ].any((a) => normalize(a).length >= 6 && contains(normalize(a))),
        )
        .toList();
    if (aliases.isNotEmpty) {
      return aliases
          .map(
            (m) =>
                PrescriptionCatalogMatch(m, PrescriptionMatchLevel.ingredient),
          )
          .toList();
    }
    final tokens = text.split(' ').where((t) => t.isNotEmpty).toList();
    final scored = <(MedicationSuggestion, int, int)>[];
    for (final medication in catalog) {
      final name = normalize(medication.name).replaceAll(' ', '');
      if (name.length < 6) continue; // Never fuzzy-match short names.
      var best = 99;
      var rawDistance = 99;
      for (var i = 0; i < tokens.length; i++) {
        var joined = '';
        for (var count = 0; count < 3 && i + count < tokens.length; count++) {
          final token = tokens[i + count];
          if (!RegExp(r'^[a-z01]+$').hasMatch(token)) break;
          joined += token;
          if ((joined.length - name.length).abs() > 2) continue;
          final candidate = _confusions(joined);
          final distance = _distance(candidate, name);
          final allowed =
              distance <= 1 ||
              (name.length >= 8 &&
                  distance == 2 &&
                  candidate.isNotEmpty &&
                  candidate[0] == name[0]);
          if (allowed && distance < best) {
            best = distance;
            rawDistance = _distance(joined, name);
          }
        }
      }
      if (best <= 2) scored.add((medication, best, rawDistance));
    }
    scored.sort((a, b) {
      final order = a.$2.compareTo(b.$2);
      return order != 0 ? order : a.$1.name.compareTo(b.$1.name);
    });
    return scored
        .take(4)
        .map(
          (m) => PrescriptionCatalogMatch(
            m.$1,
            m.$2 <= 1 && m.$3 <= 1
                ? PrescriptionMatchLevel.close
                : PrescriptionMatchLevel.tentative,
          ),
        )
        .toList();
  }

  int _distance(String a, String b) {
    var row = List.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final next = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final values = [
          row[j] + 1,
          next[j - 1] + 1,
          row[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        ];
        next[j] = values.reduce((x, y) => x < y ? x : y);
      }
      row = next;
    }
    return row.last;
  }
}
