# Isolation des données Médicaments — plan soumis à autorisation

Note : ce plan est conservé tel qu'il a été présenté avant l'autorisation.
L'implémentation autorisée et ses limites sont décrites dans [USER_ISOLATION.md](USER_ISOLATION.md).

État : **audit et sauvegarde réalisés ; aucune migration ni modification du code
exécutable appliquée**. La version de schéma déclarée par le dépôt est 6.
La version effective d'IndexedDB dans Chrome n'a pas été inspectée. La base native
Médicaments est absente du dossier Documents standard sur ce poste. La base
`sahacare_offline.db` des autres gestions n'est pas la base Médicaments et ne doit
pas être migrée dans ce chantier.

## Protection avant développement

- Branche : `feature/medication-advanced-calendar`.
- HEAD : `d933b264dc218be60f55dea72deba68e7441072e`.
- main : `d674abff1d208e34851ec1a7a32d7bedbd60fd11`.
- Index vide au début de l'audit ; les changements statistiques/design/PDF/OCR
  sont encore non committés.
- Sauvegardes complètes existantes : `C:/src/SahaCare-backup-2026-10-31` et
  `C:/src/SahaCare-backup-2026-10-31-notifications-stock-215116`. Leur existence
  ne prouve pas qu'elles contiennent les dernières améliorations OCR.
- Nouvelle copie de travail :
  `build/user-isolation-prechange-20261103-154657`, **404 fichiers**, identiques
  par SHA-256. Tous les fichiers suivis et non ignorés, plus les configurations
  `.env` et `android/local.properties` présentes, ont été copiés. Aucune valeur
  confidentielle n'a été affichée. Manifestes et patchs Git sont conservés.
- Cette nouvelle copie protège les sources/configurations ; **ce n'est pas une
  sauvegarde du navigateur, de sa base IndexedDB ou de toute la machine**.
  Aucun fichier SQLite personnel n'a été ouvert ou migré pour cet audit.

## Constats vérifiés dans le projet

1. `MedicationRepository` n'exige aucune identité et expose médicaments,
   occurrences, stock et rapports à partir d'identifiants globaux. Les accès
   directs `getById`, `update`, `markOccurrenceTaken`, `postponeOccurrence`,
   `ignoreOccurrence`, `stockMovements` et les anomalies nécessitent tous une
   vérification de propriétaire, pas seulement les listes.
2. Les traitements archivés restent utilisés dans les historiques et rapports :
   leur propriétaire doit aussi être filtré. Les statistiques et le PDF lisent
   des instantanés SQLite ; leurs calculs n'ont pas besoin de changer.
3. `AuthService.currentUser` utilise `Supabase.auth.currentUser` en mode réel.
   `onAuthStateChange` déclenche `notifyListeners` et rafraîchit le routeur.
   Il n'existe pas encore de contexte d'autorisation propre au dépôt Médicaments.
4. Versions installées : `supabase_flutter 2.18.2`, `supabase 2.16.4`,
   `gotrue 2.27.3`. Le SDK installé expose `auth.getUser(jwt)` qui appelle
   `/user` sur Supabase Auth ; c'est une vérification de l'identité du jeton,
   pas un envoi de données médicales. Une valeur d'UID dans un widget ou
   `userMetadata` ne constitue pas une preuve d'autorisation.
5. Dans ce SDK, `signOut` utilise `SignOutScope.local` par défaut et enlève la
   session locale avant l'appel réseau de révocation. Le coordinateur pourra
   observer la session et les événements existants, sans réécrire les flux
   email/OAuth/OTP ni les comportements des autres gestions.
6. La démo initialisée utilise `local-demo-user`, tandis que les connexions
   simulées utilisent `demo-user`. Le module doit normaliser ces deux identités
   fictives vers un espace démo unique seulement lorsque le mode démo est actif.
   Un email saisi en démo ne crée pas un vrai propriétaire.
7. Le registre des notifications est global et n'écoute pas les changements
   de compte. Les messages système actuels ne contiennent déjà ni nom ni dosage,
   mais leurs clés/payloads et leur synchronisation doivent être cloisonnés.
8. Le PDF et l'import OCR bloquent volontairement les comptes réels en attendant
   l'isolation. Ces protections ne devront être levées qu'après validation du
   dépôt et de la migration, jamais simplement en passant leur booléen à true.
9. Sur Web, les bases démo et réelle portent des noms distincts. Sur natif, le
   chemin Médicaments est actuellement partagé : son contenu historique ne
   prouve donc pas qu'il appartient au compte actuellement connecté.

## Architecture proposée

### Identité et session

Créer un service Médicaments indépendant des widgets :

- Identité réelle issue du jeton de session Supabase validé, avec contrôle de
  l'expiration, de l'identifiant renvoyé et du projet Supabase utilisé.
- Propriétaire canonique interne, par exemple `supabase:<projet>:<uuid>` ; espace
  distinct `demo:local` pour la seule identité fictive autorisée. Aucun `ownerId`
  fourni par l'interface ne sera accepté pour autoriser une opération.
- Au démarrage/restauration, valider l'identité auprès de Supabase avant
  d'autoriser les données réelles. Échec de validation ou session expirée :
  accès refusé, pas de repli vers la démo. Une session déjà validée et non
  expirée peut conserver un accès local jusqu'à son expiration ; après cela,
  connexion/rafraîchissement nécessaire. Cette limite hors ligne sera affichée.
- Invalidation immédiate à la déconnexion, au changement de compte ou de jeton.
  Chaque travail asynchrone reçoit une génération de session capturée ; un
  résultat A devenu obsolète ne doit pas apparaître chez B, même après A→B→A.
- Contrôler la session avant les requêtes, dans les transactions et avant de
  rendre le résultat. Ne jamais relire « le nouvel utilisateur » au milieu
  d'une écriture commencée pour l'ancien.
- Sans session autorisée, ne pas ouvrir la base médicale pour servir les données.

### Autorisation SQLite

Proposition de migration **additive 6→7**, sans reconstruction/suppression de
tables et sans changement des règles d'observance, de calendrier ou de stock :

```sql
ALTER TABLE medications ADD COLUMN owner_id TEXT;
CREATE INDEX idx_medications_owner ON medications(owner_id, deleted_at, id);
ALTER TABLE medication_notification_registry ADD COLUMN owner_id TEXT;
CREATE INDEX idx_medication_notification_owner
  ON medication_notification_registry(owner_id, id);
```

Une table de journal d'attribution sera ajoutée pour enregistrer les opérations
de récupération explicitement autorisées, sans dupliquer les textes médicaux.

Le traitement est la racine d'appartenance. Ses calendriers, heures, occurrences,
stocks et mouvements héritent de ce propriétaire par leurs clés étrangères :
une seule source d'autorité, sans colonnes propriétaire contradictoires dans
chaque table enfant. Tous les accès directs aux enfants passent par une jointure
ou un `EXISTS` sur `medications.owner_id`, y compris les anomalies/résolutions,
confirmations et accès aux occurrences par leur seul identifiant.

- Nouveaux traitements : owner injecté uniquement par le contexte de session.
- Lecture/liste/agrégat/rapport : prédicat propriétaire obligatoire, y compris
  données archivées. Un identifiant étranger doit produire le même résultat
  qu'un identifiant inexistant, sans révéler son contenu.
- Écriture : vérifier le traitement/occurrence dans la même transaction que le
  stock et le journal ; aucune écriture partielle ou croisée. Valider aussi les
  liens occurrence↔calendrier↔traitement et anomalie↔traitement.
- Registre de notifications : owner filtré et clés internes incluant le contexte
  propriétaire pour éviter de réutiliser une demande d'un autre compte.
- Les méthodes internes de chargement n'acceptent que des parents déjà autorisés.
- Le catalogue public de référence reste partagé ; ce n'est pas une donnée
  médicale personnelle.

### Transition de compte et fonctionnalités

- Un coordinateur propre au module écoute les événements d'authentification dès
  le démarrage. Seuls un branchement minimal dans `main.dart` et des protections
  des routes Médicaments seraient nécessaires hors du dossier du module.
- Au changement de génération : vider l'état médical affiché, filtres contenant
  des données, formulaires, scans et aperçus PDF. Recréer le sous-arbre Médicaments
  pour empêcher une ancienne page de conserver le traitement A sous B.
- Garder les calculs d'observance, de stock et de calendrier inchangés : ils ne
  recevront que les enregistrements autorisés.
- PDF : génération, aperçu, sauvegarde et partage liés à la même génération de
  session ; recontrôle après chaque attente et juste avant une action externe.
  Ne pas attribuer automatiquement l'identité d'un profil global au rapport.
- OCR : traitement local et validation humaine conservés ; possibilité d'ajout
  sous un compte réel seulement une fois l'accès scoped validé. Un brouillon
  capturé sous A ne peut jamais être enregistré sous B.
- Notifications : invalider la file asynchrone, annuler les seules demandes
  système du module, puis reprogrammer celles du compte actif. Conserver les
  notifications des autres gestions. Le contrôle courant de session s'applique
  également après chaque appel système asynchrone.
- Si le nettoyage des notifications échoue, afficher une erreur explicite et
  ne pas annoncer de synchronisation réussie. Garder des messages génériques,
  sans information de traitement ou identité, pour limiter les fuites lors
  d'une course ou d'une révocation distante inconnue de l'app fermée.

## Migration, sauvegarde et anciennes données

**Aucune donnée historique ne sera attribuée au premier utilisateur connecté.**
Toutes les lignes existantes resteront `owner_id IS NULL`, intouchées et hors
des lectures/exports/notifications des comptes ordinaires, y compris la démo.
Leurs enfants, dates, quantités, unités, mouvements et IDs seront conservés.

Avant une migration réelle :

1. Identifier la base Médicaments réellement utilisée (IndexedDB sur Chrome ;
   fichier natif distinct de la base des autres modules) et sa version réelle.
2. Obtenir l'autorisation explicite. Une autorisation de tests isolés ne vaut
   pas autorisation de migrer la base personnelle.
3. Faire une copie cohérente de cette base, en tenant compte des transactions
   et des fichiers WAL éventuels. Un simple copier-coller d'un `.db` actif ne
   constitue pas une sauvegarde cohérente garantie. Le stockage navigateur
   doit disposer d'une procédure d'export/validation dédiée.
4. Contrôler schéma, clés étrangères, intégrité, volumes et empreintes de la
   copie. Appliquer l'ajout en transaction et vérifier que tous les enregistrements
   historiques sont restés identiques, avec owner NULL.
5. Si la version réelle n'est pas 6, arrêter et préparer le chemin adapté ; ne
   pas exécuter automatiquement d'anciens changements structurels non examinés.

L'implémentation proposée doit comporter une barrière de consentement : une base
personnelle v6 n'est pas ouverte directement avec `version:7` tant que sa migration
n'a pas été autorisée. Aucun lancement/hot reload de la session Chrome courante
ne sera fait pendant les tests isolés.

### Attribution explicite des données historiques

Un UID authentifié prouve le compte courant, **pas la propriété d'anciennes lignes
anonymes**. Aucun bouton accessible à tous du type « récupérer tous les traitements ».

La procédure proposée reste une opération de récupération locale distincte,
autorisée pour des enregistrements déterminés et un propriétaire vérifié :

- Établir la provenance des données avec l'opérateur légitime ; sans preuve ou
  attribution fiable, les laisser non attribuées.
- Préparer un inventaire/mapping contrôlé hors des vues ordinaires, sur une copie.
  Le module ne doit pas exposer les noms historiques aux autres comptes.
- Obtenir une autorisation spécifique d'attribution, distincte de la migration.
- Affecter les racines sélectionnées, journaliser l'opération et vérifier les
  enfants dans une transaction atomique. Interdire la réaffectation de racines
  déjà possédées par un autre compte par les fonctions courantes.
- Sur Web, prévoir d'abord un export/récupération cohérent et explicitement
  autorisé ; pas d'outil d'administration accessible à tout utilisateur connecté.

L'absence de provenance est une limite réelle : aucun algorithme ne permet de
déduire sûrement le propriétaire de ces anciennes données.

## Risques et limites à annoncer

- Les anciennes données deviendront invisibles jusqu'à attribution : elles ne
  sont pas supprimées. Il faut expliquer ce changement avant la mise à jour.
- Certaines interfaces conservent de l'état asynchrone : les tests A→B et
  déconnexion pendant une opération sont aussi nécessaires que les filtres SQL.
- Un rappel déjà présenté par l'OS, une révocation distante pendant que l'app
  est fermée, un PDF déjà téléchargé ou un partage déjà déclenché ne sont pas
  révocables par un filtre SQLite. Les messages restent génériques ; tests
  Android/iOS réels nécessaires pour les annulations et le redémarrage.
- SQLite n'a pas de RLS Supabase. Cette isolation protège les accès applicatifs,
  pas un attaquant qui contrôle le système, lit les fichiers ou modifie le code.
  Le chiffrement local et la protection physique du stockage sont un chantier
  séparé, pas une propriété ajoutée par `owner_id`.
- Aucun changement de schéma Supabase, aucun déploiement serveur et aucun
  transfert de données médicales ne sont prévus.

## Matrice de tests après autorisation

Base isolée, identités fictives A/B et démo, horloge contrôlée, aucun vrai compte :

- A ne peut lister/lire/modifier/archiver/prendre/reporter/ignorer/réapprovisionner
  ou résoudre une anomalie de B, et inversement ; accès directs par ID compris.
- Calendriers, historiques archivés, graphiques, stock/journal et instantanés PDF
  ne contiennent que les lignes du compte actif. Calculs attendus inchangés.
- Sans session, session expirée/invalide, UID injecté par widget ou lease périmé :
  refus avant accès. Vérification des changements de session entre deux `await`.
- A→B→A, changement pendant une transaction, création, OCR, calcul PDF et partage :
  aucun résultat obsolète, aucune mutation attribuée au nouveau compte.
- Rappels du compte précédent annulés, demandes étrangères au module conservées,
  erreurs d'annulation et reprogrammation testées avec backend contrôlé.
- Migration v6→v7 : valeurs/IDs/comptages identiques, owner NULL sur l'historique,
  aucun débit rétroactif ; transaction annulée en cas d'erreur.
- Données sans propriétaire invisibles, attribution refusée sans autorisation
  de récupération ; journal et attribution atomiques pour les seuls IDs prévus.
- Compatibilité des fonctionnalités précédentes et petits écrans ; `flutter
  analyze`, tests ciblés/complets du module et compilation Web en copie isolée.

## Sources

- Code installé `gotrue-2.27.3/lib/src/gotrue_client.dart` : `getUser`, `signOut`.
- Code installé `gotrue-2.27.3/lib/src/types/session.dart` : expiration de session.
- https://supabase.com/docs/reference/dart/auth-currentuser
- https://supabase.com/docs/reference/dart/auth-currentsession
- https://supabase.com/docs/reference/dart/auth-signout
- https://supabase.com/docs/guides/auth/server-side/creating-a-client
