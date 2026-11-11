# Amélioration de la qualité OCR — 2 novembre 2026

Pour les règles de comptes postérieures à cette mesure, voir
[USER_ISOLATION.md](USER_ISOLATION.md). Les prétraitements et résultats ci-dessous
ne sont pas modifiés par l'isolation.

## Diagnostic et limites

Le signalement utilisateur est « 35 points techniques, aucun nom reconnu » sur
une ordonnance manuscrite. Cette ordonnance et son texte n'ont pas été collectés
pour ce chantier. Il n'est donc pas possible d'attribuer précisément cet échec
à une lettre, un médicament absent du catalogue ou un défaut d'image particulier.

Le code précédent normalisait l'orientation EXIF et la taille, puis utilisait
Tesseract sur Web. Le rapprochement approximatif ne permettait qu'une erreur sur
un nom d'un seul mot d'au moins six caractères ; ni les mots coupés ni les
substances actives n'étaient pris en compte. Les valeurs explicites pouvaient
être proposées même lorsque l'indice global OCR était faible.

Tesseract est principalement destiné à l'imprimé : les modèles existants ne
deviennent pas des modèles de reconnaissance de l'écriture manuscrite grâce à un
filtre. Voir la [FAQ officielle](https://tesseract-ocr.github.io/tessdoc/FAQ.html#can-i-use-tesseract-for-handwriting-recognition)
et les [recommandations sur les images](https://tesseract-ocr.github.io/tessdoc/ImproveQuality.html).

## Prétraitements locaux et réversibles

Le scan propose trois aperçus. **Original** reste sélectionné par défaut.
Chaque filtre repart de la même image recadrée/redressée, sans empiler les
transformations précédentes. Changer de variante invalide texte et suggestions
précédents ; un bouton restaure aussi l'image initiale.

- **Contraste et netteté douce** : fond alpha aplati sur blanc, luminance,
  correction progressive des ombres, étirement de contraste borné par histogramme,
  masque de netteté léger. Le filtre préserve les niveaux de gris.
- **Noir et blanc adaptatif** : luminance et contraste, seuil relatif à la moyenne
  locale par image intégrale. Utile pour les ombres ; peut effacer un trait fin.
- Les deux modes peuvent agrandir les petites images, au maximum ×2, avec une
  interpolation cubique. Cela n'invente pas des détails absents. La petite image
  du benchmark reste illisible : aucun gain n'est revendiqué sur ce cas.
- Recadrage manuel conservé, conseils sur la marge et ajout d'un redressement
  fin **−2° / +2°**, sur fond blanc et avec interpolation cubique. Le moteur Web
  garde également son option de rotation automatique. Pas de détection automatique
  des bords ni de correction de perspective revendiquée.

Les traitements restent locaux et utilisent `image` déjà installé. Aucun nouvel
API, modèle cloud, dépendance, réglage natif ou schéma SQLite n'a été ajouté.
Les grandes images peuvent prendre du temps ; sur Web, `compute` ne constitue
pas un Worker Dart indépendant pour ce prétraitement. L'OCR Tesseract lui-même
reste exécuté dans son Worker local.

## Mesures réelles, données entièrement fictives

Moteur Node Tesseract.js 6.0.1, mêmes modèles français/anglais que Web. La production
du texte a réellement été exécutée, sans mock, avec les variantes de production.
**Nombre de noms restitués parmi les deux noms attendus, après normalisation
typographique des espaces et de la ponctuation** :

| Fixture | Original | Contraste/ombres/netteté | Noir et blanc adaptatif |
|---|---:|---:|---:|
| Imprimé net | 2 | 2 | 2 |
| Imprimé avec ombre | 0 | 2 | 2 |
| Imprimé très petit | 0 | 0 | 0 |
| Imprimé légèrement flou | 1 | 2 | 2 |
| Segoe Print, écriture simulée | 2 | 2 | 2 |
| Pristina, cursive simulée avec ombre | 0 | 2 | 1 |

Ce petit jeu synthétique ne mesure pas la précision médicale et ne représente
pas la diversité des écritures réelles. Les indices techniques varient même
quand aucun nom n'est reconnu (78/100 sur la cursive originale avec seulement un
fragment d'en-tête). **Un indice élevé ne prouve donc pas qu'un médicament est juste.**
Le redressement fin utilise la rotation interpolée de la bibliothèque `image` ;
aucun gain chiffré spécifique au redressement n'est revendiqué sur ce jeu.

Une ablation supplémentaire a comparé **l'agrandissement cubique ×2 seul** à
l'original, sans contraste ni seuil, sur cinq réductions du texte imprimé :
250 et 300 px : 0→0 nom ; 350 et 400 px : **0→2 noms** ; 450 px : 2→2.
Le bénéfice du redimensionnement est donc observé à certaines résolutions de ce
jeu, sans récupération des détails perdus aux plus petites tailles. Résultats :
`test/fixtures/medication_ocr/resize-results.json`.

Sorties brutes fictives et mesures :
`test/fixtures/medication_ocr/benchmark-results.json`. Procédure reproductible :
`test/fixtures/medication_ocr/README.md`. Temps Node indicatifs uniquement pour
l'OCR, hors prétraitement et hors premier chargement du navigateur.

## Suggestions et vérification humaine

Le catalogue embarqué et l'autocomplétion existante sont réutilisés en mode local
uniquement. Le catalogue et la recherche des autres pages ne sont pas modifiés.

- Noms exacts : indication « nom identique », jamais une validation clinique.
- Substance active ou alias exact : marques associées dans le catalogue proposées
  explicitement, sans substitution ni choix automatique.
- Mots coupés (jusqu'à trois segments), noms composés et confusions OCR 0/o, 1/l,
  q/g interne : suggestions incertaines. Les corrections ne réécrivent pas le
  texte brut et ne s'appliquent **jamais aux dosages ni aux horaires**.
- Distance d'édition bornée : une erreur sur les noms d'au moins six lettres ;
  deux erreurs après normalisation visuelle seulement à partir de huit lettres
  et avec la première lettre conservée. Maximum quatre propositions approximatives,
  classement déterministe, aucun rapprochement flou des noms courts.
- Chaque proposition porte un motif et un niveau qualitatif (« nom proche » ou
  « ressemblance limitée / forte incertitude »), sans pourcentage de justesse.
  Cliquer une proposition renseigne le nom, pas l'acceptation. Les corrections
  des noms révoquent l'acceptation précédente et empêchent de reprendre les
  dosages, horaires et dates du médicament précédent.
- En dessous de **60 points techniques**, seuil conservateur d'interface et non
  seuil médical, même les noms exacts requièrent un choix explicite. Dosage,
  fréquence, horaires, durée et dates extraits sont ignorés. Pour les autres
  correspondances incertaines, aucun de ces champs n'est prérempli non plus.
- Le texte brut reste consultable et distinct de la copie corrigée. Un bouton
  **Choisir un médicament manuellement** permet une recherche locale même sans
  image, sans OCR ou après un échec complet.
- Une case de sélection puis le formulaire habituel et sa confirmation finale
  restent obligatoires. Aucun enregistrement automatique, rappel ou mouvement
  de stock n'est ajouté.

Exemple effectivement observé : `Dofalqon` dans la sortie cursive noir et blanc
peut proposer **Dafalgan**, avec forte incertitude et champs de posologie vides.
Cela améliore la recherche d'un candidat, pas la certitude sur le médicament.

## Confidentialité et protection du travail

Les règles de `OCR.md` restent applicables : mémoire de session, annulation et
nettoyage des fichiers de travail, pas de cloud, pas de rattachement de patient,
import réservé au compte de démonstration tant que SQLite n'est pas isolé par compte.
Les filtres n'écrivent pas d'image réelle dans le projet ni dans les fixtures.
Aucune ordonnance réelle n'a été utilisée dans les mesures ou les tests.

Les fichiers OCR préexistants ont été copiés dans
`build/ocr-quality-prechange-20261102` avant les changements. Les 32 fichiers
protégés (statistiques, PDF, stock, cadre de téléphone et autres modifications
précédentes) ont conservé leurs empreintes SHA-256, ainsi que la base personnelle.

## Fichiers de ce chantier

- Ajout : `data/services/prescription_image_processing.dart` et
  `domain/services/prescription_catalog_matcher.dart`.
- Modifications : `prescription_image_service.dart`, `prescription_scan.dart`,
  `prescription_extractor.dart`, `prescription_scan_screen.dart`,
  `prescription_review_tile.dart` et cette documentation liée depuis `OCR.md`.
- Tests : `medication_prescription_quality_test.dart`, extension de
  `medication_prescription_widgets_test.dart`, six PNG et leurs mesures sous
  `test/fixtures/medication_ocr/`.
- Reproduction : `tool/medications/generate_ocr_quality_fixtures.ps1`,
  `prepare_ocr_quality.dart`, `benchmark_ocr_quality.cjs`,
  `prepare_ocr_resize.dart`, `benchmark_ocr_resize.cjs`.

## Validation

Tests sur les limites des rapprochements, les fausses correspondances évidentes,
la qualité faible, la suppression de toute posologie incertaine, la recherche
manuelle, les variantes réversibles sans accumulation, les images déterministes
et les anciennes fonctionnalités du module. Tests exécutés dans la copie isolée
`build/adherence-validation-20261031`, pas sur la base personnelle.

Les tests de widgets sont des tests Flutter, pas une observation de Chrome.
Le benchmark Node valide le moteur, pas son pont JavaScript navigateur. La
reconnaissance d'ordonnances manuscrites réelles et les appareils Android/iOS
restent à valider ; aucune garantie de lecture n'est annoncée.

Validation finale : `flutter analyze --no-pub` sans problème ; suite Médicaments
**181 réussis, 0 échoué, 3 ignorés** (tests du rapport réservés au Web), dont
**37 tests OCR**. Journal :
`build/adherence-validation-20261031/build/ocr-quality-medication-tests-final.log`.
Les 37 tests OCR ont été revalidés après le dernier contrôle des dates
(`build/adherence-validation-20261031/build/ocr-quality-final-targeted.log`).
Compilation Web release en mode démonstration local réussie après ce contrôle :
`flutter build web --release --no-pub --no-wasm-dry-run --dart-define=SAHACARE_LOCAL_DEMO=true`.
Les comptes, la base personnelle et les autres métiers n'ont pas été utilisés
pour les mesures. Aucun commit, push ou merge.
