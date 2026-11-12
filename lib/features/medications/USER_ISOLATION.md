# Isolation des comptes — implémentation et validation

## État et périmètre

L'isolation applicative est implémentée pour les bases Médicaments en version 7.
**L'autorisation reçue couvre le code et les tests isolés uniquement. Aucune base
personnelle n'a été migrée, aucun ancien traitement n'a été attribué et la session
Chrome existante n'a pas été redémarrée.** Une application déjà ouverte avec
l'ancien code ne bénéficie pas encore de ces changements.

Le [plan présenté avant les changements](USER_ISOLATION_PLAN.md) est conservé.
La sauvegarde des sources/configurations précédentes se trouve dans
`build/user-isolation-prechange-20261103-154657` : **404 fichiers vérifiés SHA-256**,
avec états et patchs Git. Elle ne sauvegarde pas IndexedDB/les profils Chrome.
Une sauvegarde complète plus ancienne existe également à côté du projet,
`C:/src/SahaCare-backup-2026-10-31-notifications-stock-215116`, avec son `.git`.

## Autorité de session

`MedicationAccess` centralise l'autorisation du module :

- Production : session SDK Supabase présente, jeton non expiré, identité
  confirmée par `auth.getUser(jwt)` et concordance avec le compte de la session.
  Une session restaurée depuis le stockage n'est pas traitée comme vérifiée
  sur la seule foi de son UID. Le jeton n'est ni journalisé ni enregistré dans
  une table Médicaments.
- Propriétaire interne : identité du projet Supabase canonique (origine, port
  et chemin éventuel) et UUID renvoyé par le serveur. Aucun owner n'est accepté
  dans les paramètres des méthodes de lecture/écriture ou dans `Medication`.
- Démo : espace `demo:local`, distinct des vrais comptes, uniquement avec le
  mode démo et ses identités fictives reconnues. Un email saisi en démo ne
  constitue pas un nouveau compte réel.
- Chaque accès capture une autorisation **avant le premier await**. Sans session
  autorisée, refus immédiat : une écriture ancienne ne peut pas attendre la
  connexion de B et ensuite adopter son identité.
- Les générations invalident les opérations A→B→A, déconnexions, expirations et
  changements de jeton. Contrôles supplémentaires en transaction et au retour.
  Même les erreurs d'une opération devenue périmée sont remplacées par un refus
  générique : une exception SQL peut contenir d'anciens arguments médicaux.

L'adaptateur réel ne fournit jamais d'identité prévalidée issue d'un cache local.
Les autorités fictives prévalidées sont injectées **depuis les tests uniquement**.
Le contexte validé est indépendant des indicateurs affichés par les widgets
(`sessionKey`, `verified`, validation d'un brouillon OCR) : ces valeurs ne
permettent pas de contourner le dépôt ou de changer le propriétaire SQL.

L'authentification email/OAuth/OTP, `AuthService` et `SupabaseConfig` ne sont pas
modifiés. `main.dart` démarre seulement le coordinateur propre au module et la
réconciliation de ses rappels après l'initialisation d'authentification existante.

## Dépôt et tables liées

Les 20 méthodes publiques d'accès aux données du dépôt sont contrôlées : listes,
ID direct, ajout, modification, archivage, calendrier, occurrences, confirmations,
reports, prises ignorées, stock/anomalies, observance, PDF et registre de rappels.
La préparation du stockage est contrôlée aussi ; fermer une connexion ne demande
pas de lecture médicale.

`medications.owner_id` constitue l'unique racine d'appartenance. Les calendriers,
heures, occurrences, stocks et mouvements héritent de l'appartenance de leur
traitement : jointures filtrées ou contrôle du parent dans la transaction.
Les liens occurrence/calendrier/traitement et résolution/anomalie sont vérifiés.

- Médicament étranger et inexistant : même résultat, aucun nom ou contenu révélé.
- Aucune mise à jour d'owner dans les méthodes métier ; les champs sont contrôlés.
- Les opérations de stock et de prise restent atomiques, avec les reçus empêchant
  un double débit. Aucun changement de quantité fractionnaire, d'unité, de
  calcul d'observance ou de statut métier.
- Les traitements archivés restent conservés mais filtrés comme les actifs.
- Les connexions concurrentes du coordinateur et des pages partagent la même
  préparation du stockage pour éviter une ouverture/migration concurrente.

Le catalogue de médicaments demeure une référence publique partagée. Son contenu
et les calculs purs des métiers ne deviennent pas des données de compte.

## Migration additive et garde d'activation

Migration préparée **6→7** :

1. Ajout de `owner_id TEXT` nullable à `medications` et au registre de rappels.
2. Index par propriétaire.
3. Table `medication_ownership_audit`, initialement vide, prévue pour une
   récupération ultérieure explicitement autorisée.
4. Contrôles des clés étrangères et des liens de calendrier/stock. Une anomalie
   interrompt la transaction entière ; colonnes, tables et version sont annulées.

**Les lignes existantes gardent owner NULL.** Ni la première connexion, ni le
nom d'un médicament, ni un email, ni le nom « démo » d'une base ne prouvent leur
propriétaire. Elles sont conservées, mais aucun compte ordinaire ne peut les lire,
modifier, exporter, récupérer ou utiliser pour reprogrammer un rappel.

Une base existante d'une version différente de 7 déclenche
`MedicationMigrationRequired` avant l'ouverture avec `version:7`. L'interface
affiche un message de protection ; elle ne propose pas de migration automatique.
Le paramètre d'autorisation des migrations isolées exige explicitement une
factory et un chemin de test. Il n'est activé dans aucune construction du dépôt
de production et ne doit jamais être utilisé avec un chemin personnel.

Les nouveaux espaces réellement vides peuvent être créés en v7 avec des données
initialement absentes. Une ancienne base v6 nécessite encore, séparément :

- identification de la base effective et de sa version réelle, notamment dans
  le profil Chrome utilisé ; la version IndexedDB personnelle n'a pas été lue ;
- sauvegarde cohérente/export vérifié, avec prise en compte du WAL et de la
  concurrence ; la copie de sources ne remplace pas cette sauvegarde ;
- autorisation explicite de migration personnelle ;
- procédure distincte d'attribution après établissement d'une provenance fiable.

### Attribution historique : volontairement non exposée aux comptes ordinaires

Il n'existe **aucun bouton/API courant permettant de réclamer toutes les données
anonymes**. Le journal est prêt, mais aucun outil de récupération personnelle
n'a été activé ou exécuté pendant ce chantier.

La procédure décrite dans le plan reste une opération de maintenance locale
séparée : inventaire contrôlé sur copie, preuve/mapping de provenance, autorisation
pour les IDs sélectionnés et le compte vérifié, attribution atomique et journalisée,
vérification de tous les enfants. Sans provenance suffisante, conserver owner NULL.
Après attribution, d'éventuels doublons avec de nouvelles saisies doivent être
examinés explicitement, jamais fusionnés automatiquement.

## Interface, PDF et OCR

Les seules intégrations hors du module sont le démarrage dans `main.dart` et les
routes Médicaments dans `app_router.dart`. Les autres gestions ne reçoivent aucun
filtre, migration ou changement de règle.

- Les routes n'affichent leurs enfants qu'après validation de la session et du
  stockage. Une génération différente recrée l'état des écrans.
- Les fenêtres/formulaires temporaires ouverts depuis Médicaments sont fermés
  lors d'une transition de compte ; les fenêtres d'un autre module sont conservées.
  Le navigateur principal n'est pas fermé et aucune donnée n'est supprimée.
- Les formulaires sont liés à la session qui les a ouverts. Même une validation
  OCR contrôlée par l'interface ne permet pas de sauvegarder le brouillon A chez B.
- Les statistiques et rapports reçoivent des instantanés limités au propriétaire.
  La génération PDF vérifie la session après le rendu. Les artefacts conservent
  un contrôle de génération avant sauvegarde/partage et après les attentes.
- Le PDF reste sans identité patient ajoutée automatiquement. Les symptômes de
  l'orientation, hors périmètre et sans propriétaire fiable, ne sont pas importés.
- L'OCR reste local, avec corrections et confirmation obligatoires. Les comptes
  réels peuvent l'utiliser dans un contexte validé et un stockage v7 prêt ; aucune
  lecture ou écriture n'est autorisée dans une ancienne base non migrée.

## Notifications

Le registre est filtré par owner et ses clés sont séparées par propriétaire.
Les payloads nouveaux portent un identifiant opaque de génération, pas l'UID,
le nom du médicament, une dose ou une identité patient. Le texte de notification
invite simplement à ouvrir SahaCare, sans détail médical.

Le coordinateur :

- capture le contexte lors de la mise en file ;
- invalide la file et efface l'état affiché à la déconnexion/changement ;
- annule les seules demandes système du module avant la programmation de B ;
- vérifie encore le contexte après chaque attente sensible et chaque programmation ;
- garde les demandes des autres gestions et respecte les limites iOS existantes ;
- conserve avant programmation un journal technique durable des seuls IDs système
  opaques dans SharedPreferences, pour nettoyer un éventuel orphelin après crash.
  Ce journal ne contient ni propriétaire, ni médicament, ni horaire ou texte médical.

Sans session : nettoyage uniquement, aucune programmation. En cas d'échec
d'annulation : erreur explicite, compteur nul et aucune nouvelle synchronisation
annoncée comme réussie sous B. Les IDs non nettoyés restent disponibles pour réessayer.

Le navigateur reste en mode « notifications système persistantes non prises en
charge » ; aucune infrastructure Web Push n'est ajoutée.

## Limites de sécurité et de validation

- **Isolation applicative, pas chiffrement** : une personne ayant accès direct
  aux fichiers SQLite ou au profil/stockage Chrome peut contourner les filtres
  de l'application. SQLite n'applique pas une RLS Supabase. Aucun chiffrement
  par compte ni protection contre une modification du code/appareil n'est ajouté.
- Une première vérification réelle demande Supabase disponible. Une identité déjà
  validée peut rester utilisée localement jusqu'à expiration ; une révocation
  distante inconnue hors ligne ne peut pas être détectée immédiatement.
- Les formulaires/scans en cours sont invalidés lors des changements de session,
  y compris un changement de jeton, par choix conservateur. Les données SQLite
  déjà enregistrées sont conservées à la déconnexion.
- Un PDF déjà téléchargé/partagé ou une notification déjà présentée par l'OS ne
  sont pas révocables. Une demande système peut subsister si l'app est fermée,
  qu'une révocation survient à distance ou qu'une annulation OS échoue. Les messages
  sont génériques ; les erreurs ne sont jamais présentées comme une réussite.
- Les tests Supabase utilisent une autorité fictive, pas deux nouveaux comptes
  créés sur un service distant. La compilation Web n'est pas une validation du
  changement réel de compte dans Chrome.
- Notifications réelles, redémarrage Android et comportement iOS restent à tester
  sur appareils physiques ; aucun fonctionnement mobile réel n'est revendiqué.

## Validation et fichiers

Base de référence avant changement : analyse propre et 181 tests Médicaments
réussis, 3 tests Web ignorés. Les tests ultérieurs utilisent exclusivement
`build/adherence-validation-20261031` et des bases temporaires/mémoire fictives.

Nouveaux tests :

- `test/medication_user_isolation_test.dart` : A/B, IDs directs, graphes, stocks,
  anomalies, captures de session, démo, PDF, erreurs périmées, migration additive,
  quarantaine et rollback ; aucun accès personnel.
- `test/medication_user_notifications_test.dart` : annulation A avant B,
  conservation des autres modules, erreurs OS, course pendant programmation,
  déconnexion et reprise des IDs après redémarrage simulé.
- `test/medication_user_scope_widgets_test.dart` : destruction des anciennes vues,
  fenêtres médicales fermées, fenêtres étrangères conservées, formulaire périmé
  refusé même avec un indicateur d'interface forgé.
- Adaptateurs fictifs dans `test/helpers/medication_test_access.dart` ; anciens
  tests adaptés à une identité explicite et à la version 7, avec conservation
  de leurs assertions métier.

Code ajouté : `medication_access.dart`, `medication_ownership_schema.dart`,
`medication_notification_cleanup_store.dart`, `medication_scope_gate.dart`.

Code modifié : dépôt, rappels/service/backend/planificateur, sessions et actions
de rapport, fichiers de sauvegarde PDF, session/écran OCR, formulaire, écran PDF,
`main.dart` et routes Médicaments. Aucune nouvelle dépendance/configuration native.
Les sources Supabase Auth, les calculs d'observance, les règles et le design du
stock, les filtres OCR, les polices et le cadre de téléphone sont préservés.

## Inventaire de ce chantier uniquement

Fichiers créés :

- `lib/features/medications/USER_ISOLATION.md`
- `lib/features/medications/USER_ISOLATION_PLAN.md`
- `lib/features/medications/data/services/medication_access.dart`
- `lib/features/medications/data/services/medication_notification_cleanup_store.dart`
- `lib/features/medications/data/services/medication_ownership_schema.dart`
- `lib/features/medications/presentation/widgets/medication_scope_gate.dart`
- `test/helpers/medication_test_access.dart`
- `test/medication_user_isolation_test.dart`
- `test/medication_user_notifications_test.dart`
- `test/medication_user_scope_widgets_test.dart`

Fichiers déjà présents modifiés (par rapport à la sauvegarde préalable) :

- `lib/core/routes/app_router.dart`
- `lib/features/medications/data/medication_repository.dart`
- `lib/features/medications/data/services/medication_notification_backend.dart`
- `lib/features/medications/data/services/medication_notification_service.dart`
- `lib/features/medications/data/services/medication_report_actions.dart`
- `lib/features/medications/data/services/medication_report_service.dart`
- `lib/features/medications/data/services/prescription_scan_session.dart`
- `lib/features/medications/data/services/report_file_io.dart`
- `lib/features/medications/data/services/report_file_stub.dart`
- `lib/features/medications/data/services/report_file_web.dart`
- `lib/features/medications/domain/entities/medication_report.dart`
- `lib/features/medications/domain/services/medication_reminder_planner.dart`
- `lib/features/medications/OCR_QUALITY.md`
- `lib/features/medications/OCR.md`
- `lib/features/medications/presentation/screens/medication_form_screen.dart`
- `lib/features/medications/presentation/screens/medication_report_screen.dart`
- `lib/features/medications/presentation/screens/prescription_scan_screen.dart`
- `lib/features/medications/REPORT.md`
- `lib/main.dart`
- `test/medication_adherence_repository_test.dart`
- `test/medication_adherence_widgets_test.dart`
- `test/medication_form_test.dart`
- `test/medication_notification_backend_test.dart`
- `test/medication_notification_service_test.dart`
- `test/medication_notifications_web_test.dart`
- `test/medication_prescription_widgets_test.dart`
- `test/medication_report_repository_test.dart`
- `test/medication_report_test.dart`
- `test/medication_repository_test.dart`
- `test/medication_repository_web_test.dart`
- `test/medication_screens_test.dart`
- `test/medication_stock_repository_test.dart`
- `test/medication_stock_section_test.dart`

Cet inventaire distingue ce chantier des modifications antérieures toujours non committées.


## Résultats finaux — 3 novembre 2026

- `flutter analyze --no-pub` : aucun problème (17,6 s).
- `flutter test --no-pub --timeout 120s` sur tous les `medication*_test.dart` dans la copie isolée : **201 réussis, 0 échoué, 3 ignorés** (tests réservés au Web).
- Le message de migration annulée dans le journal est attendu : test de corruption historique et de rollback intégral, réussi.
- Sauvegarde préalable : **404 fichiers, 0 différence SHA-256** dans les copies. Aucun fichier original manquant.
- Comparaison au snapshot : aucune modification nouvelle hors Médicaments/tests associés, hormis les deux intégrations main/routes prévues.
- Base hors module inchangée ; aucun accès à une base Médicaments personnelle ni au profil Chrome.
- Branche feature/medication-advanced-calendar ; HEAD et main inchangés ; index vide ; aucun commit/push/merge.

- Compilation Web release en mode démo, dans la copie isolée : **réussie** (150,3 s), sans démarrage de Chrome ni migration personnelle.
- La compilation valide la compatibilité des sources Web ; les 3 tests spécifiques Web ignorés ne sont pas présentés comme exécutés.
