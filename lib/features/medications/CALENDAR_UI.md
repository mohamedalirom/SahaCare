# Calendrier thérapeutique — finition visuelle

Composition : bandeau turquoise avec repère de date, titre mensuel mis en avant, sélecteur de vues sans icônes redondantes, grille mensuelle à hauteur de cellule constante, légende incluant les reports, semaine défilante sur petits écrans et chronologie aux horaires alignés. Les noms et dosages ne sont plus limités à une ligne. Les traits de chronologie suivent la hauteur du contenu plutôt qu’une hauteur fixe.

Les méthodes de chargement, de confirmation, de report et d’ignorance du screen sont inchangées. Le calcul des couleurs de statut est conservé. Aucun changement de repository, de schéma SQLite, d’identité, de rappel ou de thème. Comparaison de l’ensemble des codes couleur des trois fichiers avant/après : identique.

Animations légères de sélection et de changement de journée ; durée nulle si `disableAnimations` est actif. Le planning est animé visuellement, sans mutation de statut ni ajout de données.

Validation : tests sur dépôts mémoire fictifs, zéro/une/quatre occurrences, vues jour/semaine/mois aux tailles 320×568, 360×640, 412×860 et 440×956 ; callbacks Pris/Reporter/Ignorer/ouverture conservés. Suite calendrier et écrans : 27 tests réussis sans avertissement de clic. Les écritures médicales ne sont pas testées sur les données personnelles.

L’analyse complète signale un diagnostic informatif préexistant dans `medication_dashboard_visuals.dart` (`unnecessary_import`, import dart:ui), hors périmètre de cette modification.
