# Rapport médical PDF à partager

# Évolution de l'isolation

Pour les règles actuelles de comptes et de stockage v7 préparé, voir
[USER_ISOLATION.md](USER_ISOLATION.md). Le document initial ci-dessous décrit le
rapport avant cette évolution ; les calculs et la mise en page sont conservés.

Accès : Médicaments → **Rapport médical** → `/medications/report`.

## Fonctionnement disponible

- Période 7 jours, 30 jours ou dates personnalisées (1 à 366 jours calendaires).
- Tous les médicaments ou un identifiant précis ; inclusion volontaire des
  traitements terminés/archivés qui recoupent la période.
- Sections optionnelles observance, historique et disponibilité des symptômes.
- Génération locale d’un PDF A4 avec couverture, traitements, tableaux de statuts,
  historique, marges, en-têtes, numéros de pages et avertissement médical.
- Polices Vera embarquées avec leur licence : accents français sans appel réseau.
- Aperçu avant export. Le navigateur utilise un Blob et son lecteur PDF intégré,
  sans PDF.js ni CDN. Android/iOS utilisent `printing` pour l’aperçu local.
- Enregistrer : téléchargement demandé au navigateur sur Web, fichier exclusif
  dans Téléchargements sur bureau ou Documents de l’application sur mobile.
  Aucun fichier existant n’est écrasé. Le succès d’un téléchargement Web doit
  être vérifié dans le navigateur, il n’est pas présenté comme une sauvegarde
  physiquement confirmée.
- Partager : `share_plus`, uniquement après clic et sur le document déjà généré.
  Le repli automatique en téléchargement est désactivé. Le résultat du dialogue
  ne prouve jamais la réception par le destinataire.

Les changements de critères invalident l’ancien aperçu. Les erreurs de lecture,
de génération et d’export sont affichées sans effacer les données. Un changement
de session invalide le document en mémoire ; des vérifications supplémentaires
interviennent avant/après collecte, rendu et actions d’export.

## Confidentialité : limitation bloquante des comptes réels

Le schéma des médicaments ne comporte pas de propriétaire `user_id`/`profile_id`.
Il serait incorrect d’associer les lignes locales au compte Supabase connecté.
L’ancien export Profil possède un repli sur le premier profil local : il n’est
**ni réutilisé ni modifié** par ce module.

Le rapport lié à un compte réel est bloqué **avant toute lecture médicale**.
Seule la session explicite `SAHACARE_LOCAL_DEMO=true`, avec l’identité technique
locale attendue, peut générer un rapport anonyme de son jeu local, après une
confirmation de revue par l’utilisateur. Le PDF précise « Données locales non
attribuées. Aucun patient identifié. » Aucun nom, email, profil de démonstration,
identifiant de compte ou information démographique ne lui est ajouté.

L’anonymat ne prouve pas la propriété des lignes : le PDF le précise. Le rapport
ne doit donc pas être présenté comme un dossier nominatif ou une garantie de
complétude. Il faut une future isolation propriétaire, et une stratégie explicite
pour les anciennes lignes non attribuées, avant d’activer les comptes réels.
Cette évolution nécessitera une analyse et une autorisation de migration séparées.

## Symptômes : données existantes et exclusion volontaire

Les symptômes sont les textes saisis dans l’orientation, sauvegardés en SQLite
dans `orientation_history.text`, avec `id`, `date`, `suggested_specialties`,
`urgency` et `advice`. La table n’a pas de propriétaire. Elle appartient à la base
partagée de profil/orientation, pas à la base Médicaments de démonstration.

Aucune requête ne lit cette table pour le rapport : elle pourrait contenir les
descriptions d’une autre personne. La section optionnelle indique :
« Aucun symptôme enregistré dans ce rapport », puis explique l’exclusion.
Cela ne signifie pas que toute l’application est dépourvue de symptômes.
Ni les conseils générés par Gemini, ni des diagnostics, ni des recommandations
ne sont importés ou inventés.

## Réutilisation et données préservées

`getReportSnapshot` est une transaction de lecture cohérente qui charge les
traitements et les occurrences, y compris les métadonnées d’archivage. Aucun
backfill du calendrier, débit de stock ou changement de statut ne se produit.
Le schéma reste en version 6 : **aucune migration ajoutée ou exécutée pour ce métier**.

`calculateRange` partage l’implémentation existante de calcul avec les statistiques
7/30 jours. La classification et le dénominateur restent inchangés : échéance
effective, futures exclues, report unique, retard de 60 min et absence de
confirmation de la veille classée manquée. Les tests comparent les taux et tous
les statuts sur 7 et 30 jours. L’heure affichée est celle de la confirmation
déclarée, jamais une preuve de l’ingestion.

Limites de volume explicites : 100 traitements, 2 000 prises, 600 caractères par
champ de traitement. Un dépassement bloque la génération, sans troncature ni
perte silencieuse. Un champ vide apparaît « Non renseigné ».

## Dépendances et fichiers

`pdf 3.13.1` et `share_plus 13.3.1` étaient déjà présents. Ajout de
[`printing 5.15.1`](https://pub.dev/packages/printing/versions/5.15.1), compatible
avec le SDK Dart 3.13 et le package PDF existant. `web 1.1.1`, déjà transitif,
devient explicite pour les Blobs et l’iframe. Aucun autre package existant n’a
été mis à jour. Les enregistrements Windows de printing sont générés par Flutter.

- Modèle : `domain/entities/medication_report.dart`.
- Lecture : `data/medication_repository.dart`.
- Calcul partagé : `domain/services/medication_adherence.dart`.
- Collecte/contrôle : `data/services/medication_report_service.dart`.
- PDF : `data/services/medication_report_pdf.dart`.
- Export : `data/services/medication_report_actions.dart`,
  `report_file_platform.dart`, `report_file_stub.dart`, `report_file_io.dart`,
  `report_file_web.dart` dans le même dossier.
- UI : `presentation/screens/medication_report_screen.dart`, accès dans
  `medications_dashboard_screen.dart` et `lib/core/routes/app_router.dart`.
- Aperçu : `presentation/widgets/report_pdf_preview.dart`,
  `report_pdf_preview_native.dart`, `report_pdf_preview_web.dart`.
- Ressources : `assets/fonts/Vera.ttf`, `VeraBd.ttf`, licence, `pubspec.yaml`,
  `pubspec.lock` ; registres Windows `.cc` et `.cmake`.
- Tests : `medication_report_test.dart`, `medication_report_pdf_test.dart`,
  `medication_report_repository_test.dart`, `medication_report_widgets_test.dart`,
  `medication_report_web_test.dart`, helpers `report_web_checks*.dart`.

## Validation

Les tests utilisent exclusivement des fixtures et des bases temporaires dans la
copie `build/adherence-validation-20261031`. Aucun PDF de validation ne contient
de données personnelles. Trois sorties sont contrôlées par Poppler et pypdf :
vide, minimal et multipage (145 prises dont 140 lignes du test de pagination).
Les pages sont rendues en PNG pour vérifier l’absence de débordement, les
répétitions d’en-têtes, les accents, les sections et la numérotation.

Les tests widgets remplacent l’enregistrement et le partage système par des
actions fictives : ils ne constituent pas une preuve de partage réel, de
réception, ni de fonctionnement natif sur téléphone.

Résultats : `flutter analyze --no-pub` sans problème ; **144 tests Médicaments
réussis, aucun échec, 3 tests Web ignorés dans le runner natif**, dont 22 nouveaux
tests PDF natifs. Le test de navigation des traitements terminés défile jusqu’au
titre, déplacé par le raccourci Rapport médical. La compilation Web JavaScript
réussit avec printing et les nouvelles ressources embarquées.

Le test Chrome isolé reste bloqué au chargement du runner, avant toute assertion.
Il a été interrompu en fermant uniquement son navigateur headless temporaire.
L’aperçu intégré, le téléchargement effectivement reçu et le partage système
dans Chrome ne sont donc pas déclarés validés. Ils restent à tester manuellement
avec un document local anonyme, ainsi que sur Android et iOS.