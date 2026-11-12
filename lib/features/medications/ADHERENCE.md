# Statistiques d’observance

## Accès

Tableau de bord Médicaments → **Mes statistiques**.
Route : `/medications/statistics` (sur Chrome, généralement
`http://localhost:58731/#/medications/statistics`).
Le serveur doit être relancé ou rechargé avec le nouveau code pour disposer
de la route. Aucune application personnelle n’est lancée par les tests.

## Données et dénominateur

`MedicationRepository.getAdherenceRecords` lit uniquement les occurrences SQLite
et les informations de leur traitement, y compris sa date d’archivage. Il ne
crée pas de prises, ne génère pas les jours manquants, ne synchronise pas les
notifications et ne modifie ni le stock ni les statuts.

Période : aujourd’hui et les 6 ou 29 dates locales précédentes, de minuit au
moment de lecture. Les lignes déjà enregistrées pour le reste d’aujourd’hui
sont visibles comme futures, mais ne contribuent pas au taux.
Les dates sont construites par calendrier local, sans soustraction de durées
de 24 heures qui pourrait décaler une borne lors du changement d’heure.

**Taux = nombre de prises confirmées échues / nombre total de prises échues
enregistrées × 100.** L’échéance est l’horaire effectif (horaire reporté si présent).
Le dénominateur inclut confirmées, manquées, ignorées, reportées échues, en retard
et en attente. Les futures sont toujours exclues, même confirmées en avance.
Sans échéance enregistrée, le taux est indéfini (« — »), jamais inventé à 0 ou 100 %.
La courbe laisse des interruptions pour les jours sans dénominateur.

Les catégories sont exclusives :

- Confirmée : statut SQLite `taken`, échéance passée ou égale au moment de lecture.
- Ignorée : statut `ignored`, échéance passée ou égale au moment de lecture.
- Reportée : statut `postponed`, échéance passée ou égale au moment de lecture.
  Un report échu d’au moins 60 min est signalé dans l’historique, sans devenir
  automatiquement une deuxième prise manquée.
- En attente : statut `scheduled`, aujourd’hui, moins de 60 min depuis l’échéance.
- En retard : statut `scheduled`, aujourd’hui, au moins 60 min depuis l’échéance.
- Manquée : statut `scheduled`, date effective antérieure à aujourd’hui local.
  Cela signifie **absence de confirmation enregistrée**, sans affirmer une absence
  physique de prise. À minuit, une prise non confirmée de la veille est manquée.
- À venir : échéance strictement future, hors dénominateur quel que soit le statut.

Une confirmation tardive (au moins 60 min après l’horaire effectif) reste dans
les confirmées ; son retard est un attribut affiché dans l’historique, pas un
second comptage. Sans `confirmed_at`, l’heure est indiquée non renseignée.
Cette heure est celle de la confirmation déclarée, pas une mesure de l’ingestion.

Le report conserve la même occurrence : son horaire d’origine apparaît dans
l’historique, son nouvel horaire détermine sa période et son jour de calcul.
Les identifiants répétés d’une même occurrence sont dédupliqués.

## Traitements terminés et archivés

Les prises enregistrées pendant la période de traitement sont conservées dans
les statistiques même après sa fin. Les obligations non réalisées dont l’horaire
effectif est postérieur à l’archivage sont exclues. Les confirmations et décisions
d’ignorance explicitement enregistrées restent consultables.
Les médicaments sont regroupés par identifiant et portent les mentions Archivé
ou Terminé. Seuls les médicaments ayant des occurrences enregistrées dans la
période apparaissent dans le sélecteur et les détails.

L’archivage existant peut déjà avoir supprimé des occurrences `scheduled`.
Les jours non générés ou les lignes précédemment supprimées ne sont pas
reconstitués. Le taux décrit les données disponibles, pas une preuve de
complétude du calendrier ou d’efficacité médicale.
Les anciens horodatages SQLite locaux sans décalage UTC ne permettent pas de
retrouver avec certitude leur fuseau historique après un voyage ou une heure
locale ambiguë ; ils sont interprétés comme heures locales enregistrées.

## Interface et actualisation

Courbe `fl_chart`, répartition avec légende textuelle, détails par médicament,
historique avec horaires initial/effectif/confirmation. Un point de courbe ou
une ligne du tableau quotidien filtre l’historique ; le filtre peut être effacé.
Le sélecteur de médicament recalcule tous les indicateurs. Le sélecteur 7/30 jours,
le bouton Actualiser, le geste de rafraîchissement, la reprise de l’application
et un minuteur d’une minute relisent SQLite. Les erreurs de lecture affichent
une action Réessayer. Les données absentes ont un état explicite.
Le cadre partagé du téléphone n’est pas modifié ; `MedicationScaffold` protège
le contenu de l’encoche. L’écran utilise le navigateur racine, hors de la barre
de navigation du tableau de bord.

## Périmètre et validation

Aucune migration : schéma inchangé en version 6. `fl_chart` était déjà installé ;
aucune dépendance ni configuration native ajoutée.

- Calcul pur : `domain/services/medication_adherence.dart`.
- Requête de lecture : `data/medication_repository.dart`.
- Écran : `presentation/screens/medication_statistics_screen.dart`.
- Accès : `medications_dashboard_screen.dart` et `lib/core/routes/app_router.dart`.
- Tests : `test/medication_adherence_test.dart`,
  `test/medication_adherence_repository_test.dart`,
  `test/medication_adherence_widgets_test.dart`.

Tests exécutés dans une copie sous `build/adherence-validation-20261031`, avec
des données fictives en mémoire ou dans des bases temporaires. Les tests SQLite
comparent les tables avant/après la consultation pour vérifier la lecture seule.
Les widgets couvrent les tailles 320×568, 360×640, 412×860, et 800×1000 avec
cadre simulé et texte agrandi, les filtres, les graphiques, les états vide/erreur,
la navigation et l’actualisation temporelle.

Résultats de validation : analyse Flutter sans problème ; suite ciblée complète
de 119 tests réussis, aucun échec, 2 tests réservés au Web ignorés dans le runner
natif. Les 27 nouveaux tests portent sur les calculs (14), la lecture SQLite (2)
et les widgets/interactions (11). Les tests existants de navigation défilent
désormais jusqu’aux cartes déplacées par le nouveau raccourci.
Compilation Web JavaScript réussie dans la copie isolée avec
`flutter build web --no-pub --no-wasm-dry-run --dart-define=SAHACARE_LOCAL_DEMO=true`.
Cette compilation ne lance pas Chrome et ne prouve pas un test manuel du
parcours dans le navigateur. Pour le mode démonstration local, lancer la session
de développement avec `flutter run -d chrome --dart-define=SAHACARE_LOCAL_DEMO=true
--web-port=58731` ; le réglage de démonstration existant exige le mode debug.

Les trois fichiers initialement hors commit et la base locale contrôlée ont
conservé leurs empreintes SHA-256. La branche et les références Git sont inchangées.
