# Images fictives pour le scanner SahaCare

Aucune ordonnance ni donnée personnelle. Les images portent « ORDONNANCE FICTIVE
– TEST » et « Ne pas utiliser comme prescription ». Deux noms attendus :
**Doliprane**, **Dafalgan**. Aucun dosage n'est recommandé par ces fixtures.

- `printed.png` : texte Arial sur fond blanc.
- `printed-shadow.png` : texte plus petit, fond avec gradient d'éclairage.
- `printed-small.png` : réduction à 250 pixels de large du cas imprimé.
- `printed-blurred.png` : flou gaussien de rayon 3 du cas imprimé.
- `handwriting-print.png` : **écriture simulée**, police Segoe Print.
- `handwriting-cursive.png` : **cursive simulée**, police Pristina, fond ombré.

Les deux dernières images sont des rendus typographiques synthétiques, pas des
ordonnances écrites par une personne. Elles permettent une comparaison reproductible,
pas une validation de l'écriture réelle d'un prescripteur. Les polices Windows ne
sont pas redistribuées, seulement les images fictives rendues.

`benchmark-results.json` contient le texte brut **fictif** réellement produit par
Tesseract.js 6.0.1 / core 6.0.0, avec les modèles locaux fra+eng best_int existants.
Les tests Flutter valident le prétraitement et l'exploitation prudente de ces
sorties ; le moteur OCR réel est exercé séparément avec le script Node ci-dessous.
Les nombres sont propres à ces six images ; ce ne sont pas des taux de fiabilité
médicale ou une mesure de précision sur des ordonnances réelles.

Reproduire depuis la racine du projet (modèles et paquets npm locaux déjà présents) :

```powershell
# Facultatif : régénérer les quatre images de base sur Windows (polices nécessaires).
& tool/medications/generate_ocr_quality_fixtures.ps1
dart run tool/medications/prepare_ocr_quality.dart
node tool/medications/benchmark_ocr_quality.cjs
# Ablation facultative du redimensionnement seul, toujours sur le texte fictif.
dart run tool/medications/prepare_ocr_resize.dart
node tool/medications/benchmark_ocr_resize.cjs
```

Le script Dart utilise la fonction de prétraitement de production et génère les
variantes sous `build/ocr-quality`. Le script Node ne lit que ces fixtures nommées
explicitement, sans SQLite ni réseau pour les images. Il charge le moteur depuis
`build/ocr-vendor/node_modules` (installation locale existante) et les modèles depuis
`web/ocr/data`. Aucun paquet n'est installé automatiquement. Les sorties suivantes
restent dans `build/ocr-quality/results.json` ; le fichier de référence ci-présent
n'est pas réécrit automatiquement.

`resize-results.json` conserve cette seconde mesure : agrandissement cubique ×2
sans autre filtre, sur cinq tailles de l'image imprimée, sans textes personnels.
