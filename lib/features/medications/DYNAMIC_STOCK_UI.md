# Flacon dynamique de stock

`DynamicMedicationBottle` est une visualisation vectorielle locale, sans accès aux données ni écriture. La carte reçoit le stock rechargé par le parcours existant de détail / mouvements ; aucune souscription globale ni notification de consommation fictive n’est ajoutée.

La quantité exacte reste prioritaire. Le flacon et la jauge utilisent `restant / max(référence enregistrée, restant)`, borné à 100 %. Il s’agit d’une **échelle visuelle explicite**, pas de la capacité physique du conditionnement. Le repository conserve sa règle existante d’augmentation de la référence après réapprovisionnement. Référence nulle et stock nul donnent un niveau nul.

Les comprimés et gélules ont un motif de dix-huit éléments maximum, symbolique et non dénombrable comme un inventaire. Les autres unités ont un niveau générique sans gélules. Aucun calcul de conversion mg/comprimés. Un stock désactivé montre un contour sans remplissage et conserve la quantité numérique historique.

Une variation enregistrée anime le niveau durant 420 ms ; aucune animation initiale depuis un faux stock et aucune boucle. La réduction des animations supprime la transition. Les nombres changent immédiatement. `RepaintBoundary` et `shouldRepaint` limitent les repeints. La description accessible mentionne quantité, unité, seuil et état désactivé.

Les badges proviennent toujours de `StockAlert`. « Niveau intermédiaire » est seulement une indication visuelle sous 50 % hors alerte ; aucun nouveau seuil métier. Les contradictions explicites comprimé/gélule dans la présentation commerciale sont signalées sans modification automatique. L’unité existante reste verrouillée selon les règles actuelles ; vérifier les réglages ne promet pas sa conversion.

Tests exclusivement fictifs : rendus 30/20/10/5/0, quatre tailles demandées, transitions de baisse et hausse, réduction des animations, mL fractionnaires, échelle dépassée, suivi désactivé, boutons. Test de bout en bout avec SQLite en mémoire : confirmation répétée, prise ignorée, report, relecture du stock et réapprovisionnement. Aucun test n’ouvre une base personnelle.

Résultats : 26 tests réussis, sans avertissement de clic. Analyse ciblée des cinq fichiers Dart concernés : aucun diagnostic. Analyse complète : un diagnostic informatif préexistant `unnecessary_import` dans `medication_dashboard_visuals.dart`, aucune erreur ni avertissement. Compilation Web de démonstration réussie.

Contrôle Chrome : hot restart de la session existante sur 58732, ouverture de la fiche et observation du flacon, de la quantité, de la jauge, du signalement de contradiction et de l’accès aux commandes. Aucun mouvement effectué sur les données du navigateur. Les variations de quantité et leurs animations ont été validées automatiquement avec des données fictives, pas en débitant le stock existant dans Chrome. Pas de notification de changement externe ajoutée : les mises à jour passent par les relectures existantes.
