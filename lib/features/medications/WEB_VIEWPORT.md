# Diagnostic Web : insets négatifs — 9 novembre 2026

## Cause immédiate

SDK local : Flutter 3.47.5, moteur af7e796e161ae0bb1ff0758c71a7105418bd9ded.
La trace observée dans Chrome sur la session démo localhost:58732 remonte à
`EngineFlutterView._handleBrowserResize`, puis `_computeOnScreenKeyboardInsets`.
Le fournisseur de dimensions calcule `physicalHeight - windowInnerHeight`,
où la seconde hauteur dépend du visualViewport et du devicePixelRatio.
L'assertion signifie que cette hauteur visible dépasse la hauteur physique
utilisée dans ce calcul. Elle est levée dans le moteur, avant les widgets.

Le SDK local préserve une ancienne taille physique pendant la saisie mobile
hors rotation. L'émulation et les redimensionnements peuvent modifier les
métriques du navigateur ; la trace seule ne permet pas de reconstruire leurs
valeurs exactes à l'instant de l'erreur.

Le correctif amont c59df99 traite le cas de hauteur préservée périmée lorsque
le viewport s'agrandit pendant la saisie. Il est absent de ce SDK local :
https://github.com/flutter/flutter/commit/c59df99ac2d443e93ba5c42fe2c6b4c1009e9a6b
Il reste à valider qu'un SDK le contenant résout aussi la séquence DevTools
de SahaCare ; aucune version stable précise n'est déclarée validée ici.

## Code SahaCare examiné

- PhoneFrameWrapper : contrainte locale 412×860, défilement et décor ; aucune
  écriture dans les métriques physiques ou les viewInsets du moteur.
- MedicationScaffold : SafeArea, Scaffold et marges positives pour l'encoche
  et la navigation ; aucun calcul d'inset négatif.
- Formulaire et calendrier : MediaQuery.copyWith ne change que le format
  horaire 24 h. Aucun remplacement des viewInsets.
- L'isolation des comptes ne change pas les métriques du navigateur.

Aucun changement du cadre protégé, du code métier, de Supabase ou du moteur
installé. Aucun filtre d'erreur, clamp applicatif, retrait d'assertion ou
passage en release pour dissimuler l'erreur.

## Utilisation compatible en attendant la validation du SDK

Pour les essais sur PC, utiliser le cadre de téléphone SahaCare avec la barre
d'émulation DevTools désactivée. Pour l'émulation, fixer le modèle, l'orientation
et le zoom avant de charger la page et de saisir du texte. Terminer la saisie
avant de changer de mode ou de dimensions. Recharger après un changement de
mode si nécessaire : cela ne demande aucune suppression du stockage.
Ce protocole réduit les transitions suspectes ; il ne corrige pas le moteur
et n'est pas une garantie pour les claviers réels Android/iOS.

La correction durable doit être évaluée avec un SDK distinct contenant le
correctif, puis avec des tests Web et mobiles. Toute installation ou substitution
du SDK partagé demande une autorisation préalable ; ne pas patcher son cache.

## Validation et limites

L'erreur était présente dans la console avec émulation iPhone 16 Pro Max.
La désactivation de l'émulation a été observée, puis le formulaire vide s'est
affiché sans augmentation du compteur d'erreurs (une erreur antérieure).
Une nouvelle reproduction contrôlée avec saisie n'a pas été établie : l'outil
de capture/ciblage natif a retourné des captures du premier plan incohérentes
et des éléments de saisie périmés. Ne pas considérer cela comme une preuve
d'absence d'erreur en mode bureau ou une validation de clavier physique.
Aucun traitement enregistré pendant ces manipulations.

Le test `test/medication_viewport_test.dart` utilise une autorité fictive et un
dépôt sans stockage. Il exerce le formulaire avec dosage focalisé à 320×568,
360×640, 440×956, 956×440 et 800×1000, insets clavier positifs puis nuls.
Il vérifie les widgets, la conservation de la saisie et l'absence d'enregistrement ;
il ne reproduit pas le fournisseur de dimensions du moteur Web.

## Résultats automatisés
- 47 tests existants ciblés : réussis (formulaire, écrans, cartes, observance, PDF et OCR).
- Nouveau test viewport/focus : 1 réussi, aucune écriture, cinq tailles avec insets clavier 180 puis 0.
- Exécution dans build/adherence-validation-20261031 avec autorités fictives et bases de test uniquement.
- Les trois fichiers protégés conservent leurs empreintes SHA-256 ; main et index Git inchangés.
- Analyse Dart ciblée du nouveau test : aucun problème.
- Pour la correction moteur : valider un SDK séparé contenant c59df99 sur copie isolée, reprendre la séquence DevTools et clavier avant toute substitution du SDK partagé.
- flutter analyze --no-pub : aucun problème dans la copie isolée (27,9 s), incluant le nouveau test.
- La première analyse lancée dans le projet est restée sans résultat et a été interrompue ; la reprise isolée est celle validée ci-dessus.
