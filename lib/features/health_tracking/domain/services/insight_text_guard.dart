/// Contrôle du texte produit par le modèle de langage avant affichage.
///
/// L'application décrit des mesures : elle ne pose pas de diagnostic et ne
/// prescrit rien. Un texte qui franchit cette limite est rejeté, et le résumé
/// calculé localement est affiché à la place.
class InsightTextGuard {
  static const int maxLength = 1400;

  static final RegExp _forbidden = RegExp(
    r"vous souffrez|vous êtes atteint|vous etes atteint|diagnosti|"
    r"hypertension|hypotension|diab[èe]t|tachycardie|bradycardie|arythmie|infection|"
    r"posologie|augmentez la dose|diminuez la dose|arr[êe]tez (votre|le) traitement|prenez (un|une|du|des) ",
    caseSensitive: false,
  );

  const InsightTextGuard();

  static final RegExp _number = RegExp(r'\d+(?:[.,]\d+)?');

  static Set<String> _numbers(String text) =>
      _number.allMatches(text).map((m) => m.group(0)!.replaceAll('.', ',')).toSet();

  /// Renvoie le texte nettoyé, ou null s'il doit être rejeté.
  ///
  /// [source] : constats calculés par l'application. S'il est fourni, tout
  /// chiffre du texte doit y figurer : un chiffre inventé par le modèle
  /// entraîne le rejet.
  String? validate(String raw, {String? source}) {
    var text = raw.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
    text = text.replaceAll(RegExp(r'[*#`_]'), '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (text.length < 20 || text.length > maxLength) return null;
    if (_forbidden.hasMatch(text)) return null;
    if (source != null && !_numbers(source).containsAll(_numbers(text))) return null;
    return text;
  }
}
