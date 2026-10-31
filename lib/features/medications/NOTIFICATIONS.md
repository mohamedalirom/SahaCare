# Rappels locaux de médicaments

## Périmètre livré

Les rappels système utilisent `flutter_local_notifications 22.3.3`,
`timezone 0.11.2` et `flutter_timezone 5.1.1`. La résolution Pub conserve
les versions préexistantes. Flutter installé : 3.47.5 / Dart 3.13.4.
Android : API minimale 24 et compilation 36 (valeurs du SDK Flutter), Java 17,
AGP 9.1.0 ; iOS : cible existante 15.0. Pas de migration Gradle/Xcode majeure.
La réception sur appareil n'est pas validée par les tests Dart.

Le service démarre à l'ouverture d'un écran Médicaments. Une fois démarré,
il se resynchronise au retour au premier plan et toutes les 15 minutes au
premier plan. Chaque mutation SQLite attend aussi une réconciliation.
Les notifications déjà confiées au système ne dépendent pas d'un timer Dart.

## Calendrier et synchronisation

- Calcul pur séparé de l'adaptateur natif : jours sélectionnés, horaires
  multiples, bornes inclusives de début/fin, traitements continus et reports.
- Les confirmations et prises ignorées excluent leur occurrence. Un archivage
  ou un rappel désactivé retire les futures demandes du traitement.
- Fuseau IANA du téléphone relu à chaque synchronisation : les horaires suivent
  l'heure locale. Une heure absente au passage à l'heure d'été est reportée à
  la première minute valide ; une heure répétée ne crée qu'une demande.
- Les changements de fuseau alors que le processus est fermé ne sont recalculés
  qu'au prochain retour dans Médicaments. La réserve déjà programmée utilise
  le fuseau de la dernière synchronisation ; ce n'est pas une correction native
  immédiate pendant l'arrêt de l'application.
- Fenêtre de 28 jours, plus le jour courant. Au plus 60 demandes iOS, diminuées
  des demandes des autres modules ; au plus 200 demandes Android.
- Une date de couverture et les limites de capacité sont affichées. Sans
  réouverture, la réserve peut s'épuiser : aucun renouvellement en arrière-plan
  illimité n'est promis.
- Le registre SQLite réserve un ID avant l'appel système. Les signatures
  distinguent horaire, fuseau et précision. La liste des demandes en attente
  du système est comparée au registre et à l'état métier. Les opérations sont
  sérialisées ; le même ID remplace une demande au lieu de la dupliquer.
- Une interruption après écriture métier ou appel système est réparée à la
  prochaine synchronisation. SQLite et le système ne partagent pas de transaction
  atomique : une annulation native peut échouer et laisser un rappel obsolète
  jusqu'à une nouvelle tentative. L'interface signale cette situation.
- Aucune utilisation de `cancelAll` : les autres gestions sont préservées.
- Message d'écran verrouillé générique, sans nom de médicament ni posologie.

## Migration SQLite

Version 4 vers 5 : création additive de `medication_notification_registry`
(identifiant, clé de prise, signature de programmation). Aucun changement des
tables médicales ni suppression de leurs lignes dans cette migration.
Les migrations plus anciennes, déjà présentes, restent inchangées.
Le test de migration compare les traitements et prises avant/après sur une
base temporaire. Les bases personnelles ne sont pas utilisées par les tests.
Revenir à un ancien binaire limité à la version 4 après migration n'est pas
une opération de retour arrière prise en charge ; conserver la sauvegarde.

## Permissions et plateformes

Android : permission de notification à partir d'Android 13, accès séparé aux
alarmes exactes, canal dédié, icône monochrome, récepteurs de programmation et
de redémarrage. Sans accès aux alarmes exactes, la programmation est approximative
et affichée comme telle. Un arrêt forcé dans les réglages Android, la batterie,
le mode Ne pas déranger ou une restriction constructeur peuvent empêcher ou
retarder les alertes. Le redémarrage restaure la réserve persistée du plugin,
pas de nouveaux rappels au-delà de cette réserve.

iOS : permissions demandées uniquement après action utilisateur. Délégué
UserNotifications pour le premier plan. La programmation n'est jamais présentée
comme une preuve de réception. Aucun entitlement APNs ou serveur n'est requis
pour ces notifications locales.

Web/Windows : aucun appel mobile de permission, de fuseau ou de programmation.
Les préférences restent enregistrées, avec explication de l'absence de rappels
persistants. Pas de Firebase, de Web Push, ni de simulation de notifications.
Le Web Push futur demanderait service worker, permission et serveur planificateur.

## Validation à faire sur appareils

Validation automatisée sur ce PC : `flutter analyze --no-pub` sans problème,
67 tests Médicaments réussis et 2 tests navigateur ignorés lors de l'exécution
native isolée. La compilation `flutter build web --no-pub
--dart-define=SAHACARE_LOCAL_DEMO=true` réussit, avec vérification Wasm préalable.
Un essai supplémentaire du test widget sous Chrome est resté bloqué dans le
chargement du lanceur de tests et a été interrompu ; il n'est pas déclaré réussi.
Les appels natifs Android sont testés avec des canaux simulés, sans émission
de notification. Aucun APK ni build iOS n'a été validé ici : aucun SDK Android
n'est installé à l'emplacement standard détecté, et iOS nécessite macOS/Xcode.

1. Android/iOS : autorisation initiale, refus, réactivation dans les réglages,
   alertes au premier plan, en arrière-plan et après fermeture ordinaire.
2. Android : refus/révocation de l'accès exact, mode approximatif, redémarrage,
   arrêt forcé et restrictions de batterie.
3. Modification, désactivation, archivage, fin de traitement, report, prise
   confirmée/ignorée : absence d'ancienne alerte après synchronisation réussie.
4. Changement de zone, transitions d'heure, date limite et épuisement de réserve.
5. iOS : demandes au-delà de la capacité, présence d'autres notifications,
   ouverture d'un binaire avec une base version 4 copiée pour le test.

## Fichiers de cette intégration

- `pubspec.yaml`, `pubspec.lock` : dépendances.
- `lib/features/medications/domain/services/medication_reminder_planner.dart` : calcul pur.
- `lib/features/medications/data/services/medication_notification_backend.dart` : adaptateur système.
- `lib/features/medications/data/services/medication_notification_service.dart` : réconciliation et états.
- `lib/features/medications/data/medication_repository.dart` : registre version 5 et notifications des mutations.
- `lib/features/medications/presentation/widgets/medication_notification_panel.dart` : autorisations et retours utilisateur.
- `lib/features/medications/presentation/widgets/medication_scaffold.dart` : initialisation et erreurs.
- Les cinq écrans `medications_dashboard_screen.dart`, `medication_form_screen.dart`,
  `medication_detail_screen.dart`, `medication_schedule_screen.dart` et
  `medication_reminder_screen.dart`, dans `lib/features/medications/presentation/screens/`.
- `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`,
  `android/app/src/main/res/drawable/ic_medication_notification.xml`.
- `ios/Runner/AppDelegate.swift`.
- `windows/flutter/generated_plugin_registrant.cc` et
  `windows/flutter/generated_plugins.cmake` : mises à jour générées par Flutter.
- Tests ajoutés : `test/medication_reminder_planner_test.dart`,
  `test/medication_notification_service_test.dart`,
  `test/medication_notification_backend_test.dart`,
  `test/medication_notifications_web_test.dart`.
- `test/medication_form_test.dart` : injection d'un dépôt en mémoire pour isoler
  les tests de formulaire du service natif.
- Ce document. Les modifications antérieures du cadre partagé et de Gemini
  sont conservées, sans retouche dans cette intégration.

## Sources techniques

- https://pub.dev/packages/flutter_local_notifications
- https://pub.dev/packages/flutter_timezone
- https://pub.dev/packages/timezone
- https://developer.android.com/develop/background-work/services/alarms
- https://developer.apple.com/documentation/usernotifications
