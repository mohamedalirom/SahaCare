# Nouvelle composition Médicaments — 9 novembre 2026

## Périmètre UI uniquement

- Hero bleu nuit, typographie contrastée et illustration vectorielle de pilule
  composée en Flutter. Aucune image distante ni dépendance ajoutée.
- Deux compteurs contrastés : traitements actifs à la date locale du jour et
  horaires prévus aujourd'hui. Données, filtres et calculs de planning inchangés.
  Aucune confirmation, aucun taux ou statut d'occurrence inventé : le calendrier
  existant reste l'accès au suivi réel (confirmations/reports/prises ignorées).
- Calendrier principal turquoise ; grille Statistiques/PDF/Stock/Rappels sur deux
  colonnes lorsque la place le permet, une colonne sur écran étroit ou texte agrandi.
- Bandeau OCR distinct. Toutes les routes existantes sont conservées.
- L'accès Stock présente un choix de traitement puis ouvre sa fiche existante,
  sans calcul, écriture ou nouveau métier. Panneau entièrement défilant, y compris
  son en-tête, pour fonctionner sur petit écran avec texte agrandi.
- Fiches médicaments : statut de traitement dérivé de ses dates, nom, dosage,
  horaires, substance/présentation si présentes et stock avec son unité explicite.
- Chronologie des horaires prévus, avec accès au calendrier pour leur suivi réel.
- États vides avec composition d'icônes et invitation vers l'ajout existant.
- Bouton Ajouter de 52 pixels, hors du contenu défilant, au-dessus de l'espace
  réservé à la navigation. Cadre de téléphone et SafeArea conservés.
- Apparition du header en 280 ms ; animation désactivée avec disableAnimations.
  Le nouveau sélecteur Stock respecte aussi cette préférence.

## Palette et protections

L'ensemble des codes ARGB des deux fichiers de présentation est identique à
celui du tableau de bord sauvegardé avant cette refonte : aucun code ajouté ni
retiré. Les transparences servent uniquement aux ombres/décorations.
Les thèmes globaux et les trois fichiers protégés sont inchangés (SHA-256).
SQLite, migrations, Supabase, isolation des comptes, calculs d'observance,
programmation des rappels, stock, génération PDF et OCR ne sont pas modifiés.

## Validation

- flutter analyze --no-pub : aucun problème, copie isolée (8,5 s, version finale).
- 26 tests ciblés réussis, aucun échec ou ignoré :
  build/adherence-validation-20261031/build/dashboard-wow-final.log.
- 320×568, 360×640, 412×860 et 440×956, avec traitements et liste vide.
- Tests supplémentaires avec texte à 160 %, réduction des animations, noms longs,
  navigation des outils, sélection de traitement pour le stock, accès Ajouter,
  conservation de l'historique et séparation entre contenu et bouton principal.
- Stock fractionnaire affiché 7,5 mL distinct du dosage déclaré en mg.
- Un débordement du panneau Stock sur 320×568 à 160 % a été corrigé avant validation.
- Branche feature/medication-advanced-calendar inchangée, index vide ; aucun
  commit/push/merge, aucune suppression ou réinitialisation de données.

## Fichiers de ce chantier

- presentation/screens/medications_dashboard_screen.dart : composition et navigation UI.
- presentation/widgets/medication_dashboard_visuals.dart : nouveaux composants visuels.
- test/medication_dashboard_design_test.dart : tests étendus.
- DASHBOARD_COMPOSITION.md : ce compte rendu.

La copie préalable se trouve dans le dossier indiqué par
build/dashboard-wow-backup-path.txt. L'état source préalable est aussi consigné
dans build/dashboard-wow-baseline.csv pour contrôler le périmètre des changements.

## Vérification Chrome

Session démo locale sur http://localhost:58732/#/medications. Compilation réussie,
puis rechargement à chaud final en 1,985 s, sans arrêt d'un autre processus.
Vérifiés visuellement : header illustré, compteurs, calendrier, grille à deux
colonnes, bandeau OCR, fiche d'un traitement existant avec statut et unité de
stock, panneau Stock compact et retour au dashboard. Aucun traitement créé,
aucune quantité modifiée. La session reste ouverte en haut du tableau de bord.

Les cartes vers les autres métiers et l'ajout sont également couvertes par les
tests de routes sur les quatre tailles. Les statuts réels de prise ne sont pas
réinterprétés par la nouvelle chronologie de planning.
