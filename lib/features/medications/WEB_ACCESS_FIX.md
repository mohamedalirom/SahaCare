# Accès Médicaments sur Chrome — 9 novembre 2026

## Deux causes distinctes constatées dans la sortie de la session Flutter

1. Lors de la relance, une base démo existait déjà. Sa sonde de version ouvrait
   SQLite avec `readOnly: true, singleInstance: false`. La version 1.2.0 de
   sqflite_common_ffi_web refuse explicitement ce second paramètre pour un
   fichier persistant : ses connexions partagent une instance SQLite et un VFS
   sans verrouillage entre connexions. Le stockage échouait avant la lecture
   de version, d'où le message générique de MedicationScopeGate. Ce message
   ne prouvait donc pas un échec de l'authentification.
2. Le bouton Réessayer rafraîchissait la session, puis appelait
   `setState(() => _prepared = ...prepareStorage())`. L'expression d'affectation
   renvoyait le Future stocké. Flutter lève alors l'assertion « callback argument
   returned a Future ». Le listener de session avait déjà lancé une préparation,
   donc ce callback en déclenchait également une seconde.

## Correction

- Gate : préparation hors des callbacks setState ; ceux-ci retournent void.
  Le listener de session pilote la préparation par génération. Le bouton de
  nouvelle tentative est protégé contre les doubles appels ; mounted est vérifié
  après l'attente. Aucun résultat asynchrone ne force l'ouverture sous un autre
  compte. Le listener est retiré à dispose.
- Une erreur de préparation pouvant précéder le montage de FutureBuilder est
  prise en charge immédiatement via Future.ignore ; le Future original reste
  fourni au builder et son erreur reste affichée. Aucun échec n'autorise le child.
- Repository : sonde Web en instance unique (`singleInstance: kIsWeb`), toujours
  readOnly. Sur natif, le comportement singleInstance false est conservé.
  `_opening` sérialise les préparations concurrentes ; la sonde est fermée avant
  l'ouverture normale. Aucun changement de schéma ou d'autorisation de migration.
- Les bases existantes autres que v7 restent bloquées en production. Les lignes
  historiques sans propriétaire restent conservées et inaccessibles.

## Validation

- Reproduction avant correctif sur la copie isolée : le nouveau test déclenche
  exactement l'assertion de la ligne 104, et constate 3 préparations au lieu de 2.
- Après correctif : 209 tests Médicaments réussis, aucun échec, 5 tests Web ignorés
  dans l'exécution native. Journal : build/adherence-validation-20261031/build/scope-fix-native.log.
- Cas nouveaux : nouvelle tentative après erreur du stockage, déconnexion pendant
  la validation, fin de validation après dispose ; autorités fictives, aucun accès
  à une base personnelle. Les anciens tests A/B et de migration isolée passent.
- flutter analyze --no-pub : aucun problème (18,9 s), copie isolée.
- Les tests Web utilisent des noms de bases fictives uniques ; aucun fichier de
  la base personnelle ou démo existante n'est choisi par ces tests.

## Fichiers concernés

- presentation/widgets/medication_scope_gate.dart
- data/medication_repository.dart (option d'ouverture Web uniquement)
- test/medication_scope_retry_test.dart (créé)
- test/medication_repository_web_test.dart
- WEB_ACCESS_FIX.md (créé)

AuthService, configuration Supabase, thèmes, migrations et autres gestions sont
inchangés. Aucun contournement d'authentification, aucune attribution historique,
aucun reset SQLite/IndexedDB, aucun commit/push/merge.

## Vérification finale

- Analyse finale incluant les tests démo Web : aucun problème (90,6 s), copie isolée.
- Session démo 58732 redémarrée à chaud en 6,9 s, stockage conservé ; aucune
  nouvelle exception reçue ensuite dans la sortie Flutter au moment du contrôle.
- Les tests automatisés Chrome sont restés au chargement de la première suite
  pendant plus de six minutes, sans résultat. La seule commande de tests créée
  pour cette validation a été interrompue ; aucun succès Web automatisé revendiqué.
- Les scénarios Web de réouverture et de refus v6 restent à exécuter complètement.
  Les ressources wasm/worker ont été copiées uniquement dans le répertoire test
  de la copie isolée, que le serveur Flutter test sert statiquement.
- Vérification visuelle réussie ensuite dans la session démo Chrome 58732 :
  nouveau tableau de bord affiché, compteurs vides cohérents, ouverture du
  formulaire Ajouter sans sauvegarde, calendrier et statistiques accessibles,
  retour au tableau de bord réussi. Émulation mobile DevTools désactivée.
  Les deux anciennes erreurs restent dans la console ; aucune nouvelle occurrence
  reçue dans la sortie Flutter après le redémarrage et ce parcours.
