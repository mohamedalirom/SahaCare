# Parcours caméra / galerie — validation du 10 novembre 2026

- Android/iOS : deux actions explicites, « Prendre une photo » et « Importer depuis la galerie ». `PrescriptionImageService` appelle `ImagePicker.pickImage` avec la source correspondante.
- L’image JPG/PNG est normalisée localement, orientée selon EXIF et réencodée sans métadonnées. Aperçu avant analyse ; rotation, redressement, recadrage manuel et variantes de contraste existants conservés.
- Seul le bouton d’analyse transmet les octets de l’aperçu courant au backend OCR. Sur mobile, ce backend utilise un fichier temporaire PNG et ML Kit latin ; sur Web, le backend distinct reste Tesseract. Aucune API médicale externe ajoutée.
- Les résultats restent des suggestions : correction et acceptation manuelles, puis formulaire existant. Aucune création automatique par la capture ou l’analyse.
- Les erreurs natives d’accès caméra/photos refusé ou restreint sont expliquées sans ouvrir automatiquement les réglages ni demander de nouvelles permissions.

## Configuration inspectée

`image_picker` 1.2.4 ; `google_mlkit_text_recognition` 0.17.1. iOS 15.5 configuré et descriptions caméra/photos présentes. `requestFullMetadata: false` conservé. Android `singleTop`, sélecteur système ; pas d’ajout de permission générale de stockage ou de caméra nécessaire pour ce parcours délégué.

## Limites et recette appareil

Validation automatisée : 39 tests OCR réussis dans `build/adherence-validation-20261031`, avec données fictives et backends injectés. Analyse ciblée des fichiers modifiés : aucun diagnostic. Analyse complète : un diagnostic informatif préexistant `unnecessary_import` dans `medication_dashboard_visuals.dart` (import `dart:ui`), aucune erreur ni avertissement. Aucun appareil mobile disponible dans `flutter devices`.

Aucun Android/iPhone connecté lors de cette validation Windows. Les tests de widgets injectent des images et un OCR fictifs : ils ne prouvent pas l’ouverture physique d’une caméra ni une reconnaissance ML Kit réelle.

Sur Android et iPhone : vérifier capture, annulation, galerie JPG/PNG, refus caméra/photos, retour après passage en arrière-plan, rotation, aperçu, analyse d’une ordonnance fictive puis correction sans enregistrement. Sur iOS, compilation/signature et essais nécessitent macOS/Xcode. Tester aussi les restrictions parentales et l’accès limité aux photos.

HEIC non pris en charge par la normalisation actuelle. La récupération via `retrieveLostData` après destruction de l’activité Android n’est pas implémentée ; une reprise doit être conçue séparément avec validation du propriétaire de session avant réaffichage.

Pas de détection automatique des contours ni de correction de perspective. Une intégration séparée pourrait évaluer un scanner de documents natif local (par exemple VisionKit iOS et scanner de documents ML Kit Android), avec revue des prérequis, du téléchargement de composants et de la confidentialité avant ajout de dépendances/configuration. Rien de cela n’est implémenté ici.
