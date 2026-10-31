# Stock des médicaments

Le suivi est facultatif et désactivé par défaut. L’unité doit être choisie
explicitement : aucune conversion entre une posologie en mg et des comprimés.
Les quantités sont des entiers en milli-unités (trois décimales maximum), afin
d’éviter les erreurs d’arrondi, y compris sur Web. Gélules, gouttes, doses,
sachets, suppositoires, patchs et unités génériques exigent des nombres entiers.
Une fraction de comprimé doit correspondre à la prescription et à la présentation.
L’unité du stock est ensuite fixe pour conserver un journal cohérent.

## Confirmation et anomalies

La confirmation, le reçu unique et le débit intégral sont une transaction SQLite.
Le reçu utilise médicament + date + heure d’origine, même après report. Une
nouvelle confirmation de la même prise ne débite jamais une deuxième fois.
Les prises ignorées ou reportées ne débitent pas et ne remboursent pas un débit
antérieur. Désactiver puis réactiver le suivi ne rattrape aucune consommation.

Si la quantité disponible est insuffisante, la prise est confirmée, le stock
reste inchangé et une anomalie est inscrite au journal : aucun débit partiel,
aucun solde négatif. Un réapprovisionnement ne relance pas le débit.
Deux régularisations explicites sont possibles :

- Dans l’historique, débiter intégralement la quantité de la prise signalée,
  si le stock est suffisant. Cette action est idempotente.
- Corriger le comptage physique avec un motif, puis cocher explicitement que
  ce comptage inclut les prises signalées. Les anomalies sélectionnées sont
  régularisées sans débit supplémentaire. La case est décochée par défaut.

Les réglages ne réécrivent jamais le solde d’un formulaire devenu ancien.
Le journal conserve l’unité, les quantités, le solde après mouvement, la date,
le motif et le lien de régularisation. L’archivage conserve le stock et le journal.
La jauge utilise la quantité de référence maximale enregistrée ; les alertes
utilisent le seuil inclusif, le stock nul et les anomalies non régularisées.

## Migration autorisée 5 vers 6

Deux tables supplémentaires : `medication_stock` et
`medication_stock_movements`. Les tables médicales, les prises et le registre
des notifications ne sont pas réécrits. Les traitements existants n’ont aucun
stock configuré. Les prises déjà confirmées reçoivent seulement un reçu à zéro,
sans débit rétroactif. La migration s’exécute dans la transaction d’ouverture
SQLite. Une ancienne application ne doit pas ouvrir une base passée en version 6.

La préparation et les validations utilisent exclusivement des bases en mémoire
ou des fichiers temporaires de test. L’application personnelle n’a pas été
relancée pour exécuter cette migration pendant le développement du stock.

## Validation

`medication_stock_test.dart` : précision, unités, seuils et non-négativité.
`medication_stock_repository_test.dart` : confirmations concurrentes, reports,
annulations de statut, suivi désactivé, corrections, réapprovisionnement,
anomalies, archivage, transactions et migration 5 vers 6 avec comparaison des
lignes existantes et réouverture.
`medication_stock_widgets_test.dart` : couleurs, jauge, activation volontaire,
validation des unités, écrans 320×568 et 412×860 avec texte agrandi.
`medication_stock_section_test.dart` : dialogues et régularisation volontaire,
avec un dépôt de test ; la persistance réelle est couverte séparément.

Une vérification manuelle de bout en bout dans l’application reste à effectuer
après validation des modifications et sauvegarde des données personnelles.

Résultat de la suite ciblée native : 92 tests réussis, aucun échec et 2 tests
réservés au Web ignorés. `flutter analyze --no-pub` ne signale aucun problème.
La compilation Web JavaScript en mode démonstration local est réussie dans la
copie isolée (`flutter build web --no-pub --no-wasm-dry-run
--dart-define=SAHACARE_LOCAL_DEMO=true`). Cela ne remplace pas un test manuel
dans Chrome et n’exécute pas de migration dans le stockage du navigateur.

## Fichiers de cette évolution

- `domain/entities/medication_stock.dart` et `domain/entities/medication.dart`.
- `data/medication_repository.dart` : migration et transactions du stock.
- `presentation/widgets/medication_stock_form.dart`,
  `medication_stock_card.dart`, `medication_stock_section.dart`.
- `presentation/screens/medication_form_screen.dart`,
  `medication_detail_screen.dart`, `medications_dashboard_screen.dart`,
  `medication_schedule_screen.dart` : intégration du stock.
- `test/medication_stock_test.dart`, `medication_stock_repository_test.dart`,
  `medication_stock_widgets_test.dart`, `medication_stock_section_test.dart`.
- `test/medication_notification_service_test.dart` : fixture de migration v6.
- `test/medication_form_test.dart`, `test/medication_screens_test.dart` :
  horloge SQLite et défilement adaptés au formulaire et à la fiche enrichis.

Les autres modifications déjà présentes dans le dépôt sont conservées.
