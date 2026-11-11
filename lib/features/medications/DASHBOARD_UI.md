# Refonte du tableau de bord — 9 novembre 2026

Périmètre : présentation du seul écran Médicaments & Traitements.

- En-tête avec emblème médical, titre et hiérarchie typographique retravaillés.
- Vue d'ensemble compacte : traitements actifs à la date locale du jour et
  nombre d'horaires prévus aujourd'hui issus des traitements déjà chargés.
  Aucun compteur de confirmations inventé ; les occurrences, reports et calculs
  d'observance ne sont pas modifiés. Ce résumé des horaires n'est pas un relevé
  des statuts réels : le calendrier existant reste l'accès au suivi des prises.
- Accès calendrier turquoise conservé, cartes Statistiques/PDF/OCR regroupées.
- Filtres Actifs/Terminés/Tous déplacés auprès de la liste ; règles inchangées.
- Coins harmonisés, bordures et ombres discrètes, état vide illustré par une icône.
- Bouton Ajouter de 48 px dans son emplacement réservé, hors du défilement et
  au-dessus de l'espace prévu pour la navigation.
- Panneau de notifications inchangé, placé auprès de l'accès Rappels.

## Palette et protections

Tous les codes ARGB du tableau de bord sont identiques avant/après : aucun
ajout ni retrait. Les ombres utilisent les couleurs existantes avec transparence.
Thème global, cadre de téléphone et autres gestions inchangés. Aucune modification
de SQLite, migration, calcul métier, stock, notification, rapport, OCR ou autorisation.

## Validation

- flutter analyze --no-pub : aucun problème dans la copie isolée (10,5 s).
- 21 tests ciblés réussis, aucun échec, aucun ignoré, dans
  build/adherence-validation-20261031/build/dashboard-design-final.log.
- Tailles : 320×568, 360×640, 412×860, 440×956 ; les anciens tests vérifient aussi
  le cadre simulé, l'encoche, la navigation et le parcours de modification.
- Tests des routes calendrier/statistiques/PDF/OCR/rappels/détail/ajout,
  filtre des traitements terminés, compteurs et absence de chevauchement du bouton.
- Deux anciennes interactions de test adaptées à la nouvelle position des cartes,
  sans retrait d'assertions de navigation ou d'historique.
- Empreintes des trois fichiers protégés inchangées ; main et index inchangés.

## Fichiers de ce chantier

- Modifié : presentation/screens/medications_dashboard_screen.dart.
- Modifié : test/medication_screens_test.dart (défilement des tests).
- Créé : test/medication_dashboard_design_test.dart.
- Créé : DASHBOARD_UI.md.

La copie avant refonte du tableau de bord est conservée dans
build/dashboard-ui-prechange/medications_dashboard_screen.dart.
