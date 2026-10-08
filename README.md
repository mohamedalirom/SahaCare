# SahaCare 🏥

**SahaCare** est une application mobile Flutter dédiée à la gestion personnelle de la santé. Elle permet l'organisation, la centralisation et le suivi des informations médicales personnelles (dossiers, rendez-vous, prescriptions, etc.) pour les différents profils d'utilisateurs : **Patient**, **Médecin** et **Administrateur**.

> ⚠️ **Note importante :** SahaCare est un outil d'organisation et de suivi, pas un outil de diagnostic médical.

---

## 👥 Organisation de l'équipe

Le projet est conçu pour une équipe de 5 développeurs travaillant de manière modulaire et découplée (architecture **Feature-First**).

---

## 🛠️ Prérequis

Avant de lancer le projet, assurez-vous d'avoir installé :
1. **Flutter SDK** (version 3.47+ stable / Dart 3.13+) : [Guide d'installation Flutter](https://docs.flutter.dev/get-started/install)
2. **Android Studio** ou **VS Code / Antigravity IDE** avec les extensions Flutter & Dart.
3. **Android SDK** et un émulateur Android configuré (ou un appareil physique en mode débogage USB).

---

## 🚀 Démarrage rapide

1. **Cloner ou récupérer le projet** :
   ```bash
   cd sahacare
   ```

2. **Installer les dépendances** :
   ```bash
   flutter pub get
   ```

3. **Lancer l'application** :
   ```bash
   flutter run
   ```

4. **Lancer les tests et l'analyse statique** :
   ```bash
   flutter test
   flutter analyze
   ```

---

## 📦 Dépendances principales

- **`flutter_riverpod`** : Gestion d'état réactive et injection de dépendances.
- **`go_router`** : Routage déclaratif et navigation.
- **`dio`** : Client HTTP robuste pour les appels API.
- **`shared_preferences`** : Stockage local clé/valeur pour les préférences utilisateur et tokens.
- **`intl`** : Internationalisation et formatage des dates/heures.

---

## 📂 Structure du projet (Feature-First)

```text
lib/
├── main.dart                 # Point d'entrée de l'application (ProviderScope)
├── app.dart                  # Configuration MaterialApp.router & thème
├── core/                     # Éléments partagés et transverses
│   ├── theme/                # Thème Material 3 (palette santé bleu/vert médical)
│   ├── constants/            # Constantes globales de l'application
│   ├── utils/                # Fonctions utilitaires (formatage dates, validations)
│   ├── widgets/              # Widgets réutilisables (boutons, cartes, dialogue)
│   └── routes/               # Configuration du routeur (app_router.dart)
└── features/                 # Modules métiers développés par chaque membre
    └── .gitkeep
```

---

## 📐 Règle de développement des modules (Clean Architecture modulaire)

Chaque membre de l'équipe est responsable de son propre module fonctionnel.  
**Règle obligatoire :** chaque module doit être créé dans un sous-dossier de `lib/features/<nom_module>/` avec la structure suivante en 3 couches :

```text
lib/features/<nom_module>/
├── data/                     # Sources de données, modèles DTO, repositories implémentations
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/                   # Logique métier pure, entités, repositories interfaces, usecases
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/             # Interface utilisateur, widgets du module, providers Riverpod
    ├── controllers/
    ├── screens/
    └── widgets/
```

### Intégration des routes
Une fois votre écran principal développé, ajoutez votre route dans [lib/core/routes/app_router.dart](file:///c:/Users/dali/Desktop/SahaCare/sahacare/lib/core/routes/app_router.dart) sous le commentaire dédié :
```dart
// Ajoutez vos routes de module ici
GoRoute(
  path: '/votre-module',
  name: 'votre-module',
  builder: (context, state) => const VotreScreen(),
),
```
