# Ordonnances : OCR local et validation humaine

Les règles de comptes et d'autorisation décrites initialement ci-dessous sont
complétées par [USER_ISOLATION.md](USER_ISOLATION.md) pour le stockage v7 préparé.

Pour les prétraitements, les suggestions enrichies et les mesures du 2 novembre,
voir [OCR_QUALITY.md](OCR_QUALITY.md), qui complète les détails initiaux ci-dessous.

## Accès et périmètre

Médicaments → **Scanner une ordonnance** (`/medications/scan`). Import JPG/PNG,
aperçu, rotation de 90°, recadrage, analyse locale et reprise de l'analyse.
Sur Android/iOS, un bouton caméra utilise le sélecteur système. Sur Web,
le sélecteur de fichiers est disponible ; ML Kit n'est jamais invoqué.

Le texte brut reste consultable pendant la session. Une copie corrigible sert
à rechercher les suggestions dans le catalogue **local uniquement**. Modifier
ce texte invalide les suggestions précédentes. Les images, textes et brouillons
ne sont ni sérialisés ni envoyés au moteur de recherche distant du catalogue.

Chaque suggestion reste décochée initialement. L'utilisateur peut corriger le
nom, la présentation, le dosage, les heures et la durée ou rejeter la suggestion.
Les choix et corrections sont conservés pendant le défilement. Chaque traitement
sélectionné passe ensuite par le formulaire existant, avec une confirmation
supplémentaire obligatoire. Les doublons de nom demandent une autorisation
explicite ; fermer/annuler le formulaire ne crée rien. Les formulaires déjà
enregistrés sont retirés de la sélection pour cette analyse.

## Extraction prudente

- Les noms sont des correspondances avec le catalogue embarqué, pas des
  médicaments inventés. Une distance typographique minimale peut proposer un
  nom incertain, sans préremplir sa posologie.
- Plusieurs noms sur une ligne sont proposés séparément ; les valeurs communes
  de cette ligne ne leur sont pas attribuées.
- Un dosage unique, des heures explicites, une durée en jours et des dates
  explicites peuvent être proposées pour une seule correspondance exacte.
  L'utilisateur doit les vérifier ; une correspondance lexicale n'est pas une
  validation médicale. Aucun mg n'est transformé en comprimés.
- « 3 fois par jour » ne devient pas trois horaires. « Toutes les 8h » n'est pas
  interprété comme 08:00. Une durée ne détermine aucune date de début/fin.
- Aucune présentation n'est choisie par défaut. Les rappels et le stock sont
  désactivés dans le formulaire issu du scan ; leur activation reste manuelle.
- Maximum 30 000 caractères et 40 suggestions par analyse.

## Moteurs et dépendances autorisés

`image_picker 1.2.4`, `google_mlkit_text_recognition 0.17.1`, `image 4.12.0`.
La version image était déjà transitive ; sa version est conservée, maintenant
déclarée directement. Aucun schéma SQLite n'est modifié.

- Android/iOS : reconnaissance latine locale ML Kit. Le projet utilise Java 17,
  compile/target SDK 36 et min SDK 24 via sa version Flutter. Aucune permission
  Android de stockage étendue ni caméra supplémentaire n'est ajoutée pour les
  sélecteurs système.
- iOS : cible 15.5 (exclut 15.0–15.4), descriptions caméra/photos et Podfile
  Flutter standard pour l'intégration CocoaPods de ML Kit. Compilation sur Mac,
  résolution des pods et tests physiques restent indispensables, notamment avec
  le projet qui utilise aussi Swift Package Manager. Rien n'a été compilé pour
  iOS sur ce poste Windows.
- Chrome/Web : Tesseract.js **6.0.1**, core **6.0.0**, modèles français/anglais
  `@tesseract.js-data/{fra,eng} 1.0.0`, variante `4.0.0_best_int`. Scripts,
  WebAssembly et modèles sont servis depuis `web/ocr/` par le même hébergement
  que l'application. Pas de CDN ni API cloud de secours. Premier chargement
  conséquent (environ 21 Mo avant compression HTTP), WebAssembly/Workers requis.
  Les ressources applicatives peuvent être mises en cache par le navigateur ;
  le moteur utilise `cacheMethod: none` pour ne pas y écrire les ordonnances.

Licences officielles et manifeste d'empreintes : `web/ocr/licenses/` et
`web/ocr/SHA256.csv`. Tesseract.js/core et tessdata amont : Apache 2.0 ; les
paquets npm des modèles déclarent MIT pour leur emballage. Modèles et scripts
distribués sans modification ; `sahacare_ocr.js` est l'adaptateur SahaCare.

Sources :
- https://pub.dev/documentation/google_mlkit_text_recognition/latest/
- https://pub.dev/packages/google_mlkit_text_recognition/changelog
- https://pub.dev/packages/image_picker
- https://github.com/naptha/tesseract.js/blob/master/docs/local-installation.md
- https://github.com/naptha/tessdata/blob/gh-pages/LICENSE

## Confidentialité et limites

Les lignes médicaments SQLite n'ont pas encore de propriétaire de compte.
**L'enregistrement depuis le scan est donc limité au mode démonstration local
avec l'identifiant `local-demo-user`. Il est bloqué pour un compte réel.**
L'OCR et la correction en mémoire restent possibles sans rattacher d'identité.
Une isolation des données nécessitera un chantier distinct avant d'ouvrir
l'import aux vrais comptes. Aucun nom de patient extrait n'est utilisé.

Effacer le scan, changer de session ou quitter la page abandonne les données
en mémoire et annule/ignore le résultat d'une analyse en cours. Le navigateur
libère ensuite ces objets selon son ramasse-miettes : ce n'est pas un effacement
forensique de la mémoire. Les fichiers de galerie originaux ne sont pas effacés.
Sur mobile, la copie caméra située dans le cache privé est nettoyée après lecture ;
le fichier PNG de travail, dans un sous-dossier propre à l'analyse, est supprimé
dans `finally`. ML Kit ne permet pas d'interrompre immédiatement une requête
native ; son résultat est invalidé et le nettoyage suit sa fin. Un arrêt brutal
du processus peut laisser un fichier dans le cache système jusqu'à son nettoyage.
La récupération automatique d'une capture après destruction du processus Android
n'est pas implémentée pour éviter de restaurer une ordonnance dans une autre session.

Pas de PDF en entrée, pas de garantie pour une écriture manuscrite ou une photo
floue. Les accents latins sont reconnus ; les autres écritures ne sont pas
configurées. Le score de confiance technique Web n'est jamais une certitude
sur un médicament ou une dose. Une faible confiance invite à reprendre la photo.

## Fichiers du chantier

- `domain/entities/prescription_scan.dart`, `domain/services/prescription_extractor.dart`.
- `data/services/prescription_image_service.dart`, `prescription_camera_cleanup_{io,stub}.dart`.
- `data/services/prescription_ocr_{backend,factory,native,web,stub}.dart`, `prescription_scan_session.dart`.
- `presentation/screens/prescription_scan_screen.dart`, `presentation/widgets/prescription_review_tile.dart`.
- Intégration : `medication_form_screen.dart`, `medications_dashboard_screen.dart`,
  `autocomplete_medication_field.dart`, `lib/core/routes/app_router.dart`.
- `pubspec.yaml`, `pubspec.lock`, `ios/Podfile`, `ios/Runner/Info.plist`,
  `ios/Runner.xcodeproj/project.pbxproj`, deux fichiers générés Windows
  (`generated_plugin_registrant.cc`, `generated_plugins.cmake`) pour le sélecteur.
- `web/ocr/` : moteur embarqué, modèles, adaptateur, licences et SHA-256.
- `test/medication_prescription_test.dart`, `test/medication_prescription_widgets_test.dart`.

Les statistiques, le design du stock et le rapport PDF préexistants restent
non committés. Les 44 fichiers initialement modifiés/nouveaux ont été copiés et
vérifiés par SHA-256 avant le chantier dans `build/ocr-prechange-20261101-224246`.

## Validation

Tests exécutés dans `build/adherence-validation-20261031`, pas sur la base
personnelle. Tests de calcul lexical, ambiguïtés, doublons, images invalides,
rotation/recadrage, catalogue sans accès réseau (y compris erreur locale),
validation opt-in, correction, effacement, échec OCR et formulaires avec confirmation.
Widgets à 320, 412 et 900 px. Les mocks de widgets ne valident pas ML Kit.

Test **réel du moteur Tesseract sous Node**, mêmes versions et modèles locaux,
sur trois images entièrement fictives générées dans `build/ocr-fixtures` :

| Image | Confiance technique | Deux noms et heure explicite retrouvés |
|---|---:|---|
| Nette | 94 | Oui |
| Inclinée 5° | 82 | Oui |
| Très floue | 28 | Non |

Ce résultat n'est pas une validation du pont JavaScript dans Chrome ni de ML Kit.
Voir `build/ocr-fixtures/results.json`. Aucune ordonnance personnelle n'a été utilisée.
Les autorisations refusées, la caméra, l'OCR ML Kit et les fichiers temporaires
doivent encore être observés sur Android et iOS réels. Aucun appareil mobile
n'a été testé dans ce chantier.

Résultats : `flutter analyze --no-pub` sans problème ; suite Médicaments
**165 réussis, 0 échoué, 3 ignorés** (tests du rapport réservés au Web).
Les **21 tests OCR** ont également été revalidés après le dernier renforcement
de l'effacement de session et de l'aperçu de recadrage.
Compilation Web release en mode démo réussie. Journaux dans
`build/adherence-validation-20261031/build/medication-ocr-tests-final.log`.
Les tests Chrome isolés n'ont pas démarré et ont été interrompus ; une première
tentative parallèle avait aussi rencontré un verrou Windows sur la DLL SQLite
de la copie de test. Aucun résultat visuel Chrome ni OCR via le pont JavaScript
du navigateur n'est revendiqué. Le test moteur Node ne remplace pas ce contrôle.
