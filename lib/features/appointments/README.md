# Module Rendez-vous & Médecins (`appointments`) 🏥

Ce module gère l'ensemble du cycle de vie des consultations médicales, le carnet de médecins du patient et la localisation des professionnels de santé à proximité.

---

## 🏗️ Architecture du module

Le module respecte strictement les principes de la **Clean Architecture** et l'organisation **Feature-First** recommandée pour SahaCare :

```text
lib/features/appointments/
├── data/                         # Couche Données
│   ├── datasources/              # SQLite (DoctorLocalDataSource, AppointmentLocalDataSource)
│   ├── models/                   # Modèles DTO (DoctorModel, AppointmentModel)
│   └── repositories/             # Implémentations des repositories
├── domain/                       # Couche Métier (Pure Dart)
│   ├── entities/                 # Entités (Doctor, Appointment, AppointmentStatus)
│   ├── repositories/             # Contrats des repositories
│   └── usecases/                 # Cas d'usage métier (CRUD RDV & Médecins)
├── presentation/                 # Interface Utilisateur & Contrôleurs
│   ├── controllers/              # Notifiers Riverpod (State / AsyncNotifier)
│   ├── screens/                  # Écrans (Dashboard, Prise de RDV, Détails, Édition)
│   └── widgets/                  # Cartes, sélecteurs, dialogues
├── nearby/                       # 🌟 SOUS-MODULE : Praticiens à proximité
│   ├── data/                     # LocationService, OverpassService, NearbyCacheService
│   ├── domain/                   # NearbyPlace, NearbyCategory, NearbyRepository
│   └── presentation/             # NearbyNotifier, NearbyScreen, NearbyDetailBottomSheet
└── orientation/                  # 🤖 SOUS-MODULE : Orientation vers la bonne spécialité (LLM Gemini)
    ├── data/
    │   ├── constants/            # OrientationConstants (prompt, schéma JSON, mapping mots-clés)
    │   ├── datasources/          # GeminiService, OrientationLocalDataSource
    │   ├── models/               # OrientationHistoryEntry
    │   └── repositories/         # OrientationRepositoryImpl
    ├── domain/
    │   ├── emergency_detector.dart # Détection d'urgence locale (FR, EN, AR) sans LLM
    │   ├── entities/             # OrientationResult, OrientationRecommendation
    │   └── repositories/         # OrientationRepository
    └── presentation/
        ├── controllers/          # OrientationNotifier & OrientationState (Riverpod 3)
        ├── screens/              # OrientationScreen, OrientationHistoryScreen
        └── widgets/              # OrientationEmergencyDialog, OrientationConsentBottomSheet, OrientationResultView
```

---

## 🌟 Fonctionnalité : Médecins & Cliniques à Proximité

Cette fonctionnalité permet aux patients de géolocaliser instantanément les professionnels et établissements de santé autour d'eux sur une carte interactive OpenStreetMap, de filtrer par catégorie et rayon, de lancer des itinéraires et d'enregistrer des praticiens dans leur carnet personnel pour prendre rendez-vous.

### 📍 Points clés & Capacités

1. **Carte interactive OpenStreetMap** :
   - Rendu fluide via `flutter_map` avec attribution légale OSM.
   - Marqueur animé et pulsé pour la position actuelle de l'utilisateur.
   - Marqueurs distinctifs et colorés par type d'établissement (médecin, clinique, hôpital, dentiste, pharmacie).
   - Recentrage automatique et zoom fluide.

2. **Recherche & Filtrage dynamique** :
   - **Rayon ajustable** : 1 km, 3 km, 5 km, 10 km.
   - **Filtres par catégorie** :
     - 🩺 **Médecin** (`amenity=doctors`)
     - 🏥 **Clinique** (`amenity=clinic`)
     - 🏢 **Hôpital** (`amenity=hospital`)
     - 🦷 **Dentiste** (`amenity=dentist`)
     - 💊 **Pharmacie** (`amenity=pharmacy`)
   - **Recherche textuelle** : filtrage instantané par nom, adresse ou spécialité médicale.

3. **Fiche détaillée & Actions rapides (`NearbyDetailBottomSheet`)** :
   - Affichage de la distance calculée en temps réel.
   - Statut d'ouverture / fermeture (tags `opening_hours`).
   - Accessibilité fauteuil roulant (`wheelchair`).
   - Prise de contact directe :
     - 📞 **Appeler** (`url_launcher` via schéma `tel:`).
     - 🧭 **Itinéraire** (ouvre Google Maps ou navigation GPS).
     - 🌐 **Site web** (consultation de la page officielle).

4. **Intégration SQLite (Carnet de Médecins)** :
   - Bouton **« Enregistrer dans mon carnet »** : insère le praticien dans la table `doctors` SQLite locale.
   - **Détection des doublons** : vérifie par nom et coordonnées/adresse si le médecin est déjà présent.
   - Redirection immédiate vers **« Prendre RDV »** avec le praticien pré-sélectionné.

---

## 🛡️ Respect des Politiques OpenStreetMap & Résilience

Le service `OverpassService` applique scrupuleusement la [Overpass API Acceptable Use Policy](https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_API_Usage_Policy) :

| Exigence | Implémentation |
| :--- | :--- |
| **User-Agent d'identification** | En-tête personnalisé `SahaCare-App/1.0 (contact@sahacare.tn)` sur chaque requête HTTP. |
| **Cache local (30 min)** | `NearbyCacheService` stocke en mémoire les résultats pendant 30 minutes. |
| **Protection de la vie privée** | Arrondissement des coordonnées GPS à ~100 mètres (3 décimales) avant envoi au serveur. |
| **Multi-miroirs Overpass** | En cas de surcharge d'un serveur public, bascule automatique entre `overpass-api.de`, `kumi.systems` et `private.coffee`. |
| **Mode Fallback & Hors-ligne** | Si les serveurs OSM Overpass sont indisponibles ou bloqués par CORS (web mobile), des données contextuelles de santé autour de la position réelle de l'utilisateur sont proposées avec réessai possible. |

---

---

## 🤖 Fonctionnalité : Orientation vers la Bonne Spécialité (IA Gemini)

Cette fonctionnalité permet au patient de décrire ses symptômes en langage naturel (français, anglais ou arabe). L'intelligence artificielle (Google Gemini) analyse la description et suggère **uniquement** la ou les spécialités médicales les plus adaptées issues de la base SQLite.

> ⚠️ **RÈGLE ABSOLUE & CADRE LÉGAL :** L'application **NE DIAGNOSTIQUE PAS**. Elle oriente exclusivement vers une spécialité médicale. Aucun nom de maladie n'est présenté comme un diagnostic, et aucun médicament, dosage ou traitement n'est suggéré.

---

### 🔄 Schéma du Flux Fonctionnel

```text
Saisie des symptômes (FR / EN / AR)
               │
               ▼
   [1. Détection locale d'urgence] ────(Drapeau rouge)────► [Écran d'alerte rouge / Appel SAMU 190]
               │                                                    │
        (Aucune urgence)                                   (Continuer quand même)
               │                                                    │
               ▼                                                    ▼
   [2. Consentement IA mémorisé ?] ───(Non)───► [Bottom Sheet Confidentialité] ──► (J'accepte)
               │
               ▼
   [3. Appel API Gemini (JSON structuré)] ◄─── Liste des spécialités autorisées (SQLite)
               │
     ┌─────────┴─────────┐
     ▼                   ▼
(Erreur réseau /   (Réponse JSON valide)
 Clé manquante)          │
     │                   ▼
     │         [4. Validation stricte & Filtrage] (Rejette spécialités inconnues)
     │                   │
     │                   ▼
     │         [5. Association aux Médecins du Carnet SQLite]
     │                   │
     ▼                   ▼
[Mode Dégradé   [6. Affichage Fiche Résultat & Actions Rapides]
 Hors-ligne]             ├── Prendre RDV (pré-rempli)
 (Mots-clés)             ├── Appeler directement
                         ├── Ajouter un médecin
                         └── Chercher à proximité (OpenStreetMap)
```

---

### 🔑 Configuration de la Clé API Gemini (`.env`)

1. **Obtenir une clé API gratuite** :
   - Rendez-vous sur [Google AI Studio](https://aistudio.google.com/).
   - Connectez-vous avec votre compte Google et cliquez sur **« Get API key »**.
   - Créez une nouvelle clé pour le projet.

2. **Créer son fichier `.env` local** :
   - Copiez le fichier modèle à la racine du projet `sahacare/` :
     ```bash
     cp .env.example .env
     ```
   - Éditez `.env` et collez votre clé :
     ```env
     GEMINI_API_KEY=AIzaSy...VotreCleIci...
     ```

3. **Consignes d'équipe & Git** :
   - Le fichier `.env` est **strictement ignoré** par Git (`.gitignore`).
   - **Chaque membre de l'équipe doit avoir sa propre clé** et ne JAMAIS la commiter.
   - Si le fichier `.env` est absent ou si la clé n'est pas renseignée, l'application **ne plante pas** : elle affiche un message clair invitant à configurer la clé ou à basculer vers le **mode dégradé hors-ligne**.

4. 🔒 **Note de sécurité & Architecture en Production** :
   - Dans le cadre de ce prototype universitaire, la clé API est chargée côté client via `flutter_dotenv`.
   - **En environnement de production**, une clé API embarquée dans une application mobile peut être extraite par décompilation (reverse engineering). Il est donc indispensable d'intermédier les requêtes via un **backend proxy sécurisé** (ex: Supabase Edge Functions, Cloud Run) chargé d'authentifier le patient et de masquer la clé API.

---

### 🛡️ Sécurité Médicale & Confidentialité

1. **Détection locale d'urgence (`EmergencyDetector`)** :
   - Analyse instantanée sans appel réseau en FR, EN et AR (insensible aux accents et à la casse).
   - Détecte les signes d'alerte vitale : douleur thoracique / oppression, détresse respiratoire, perte de connaissance, AVC / paralysie soudaine, convulsions, hémorragie sévère, choc allergique, forte fièvre du nourrisson, pensées suicidaires.
   - Alerte rouge prioritaire proposant l'appel immédiat au **190 (SAMU Tunisie)** avec option d'appel bienveillant pour la détresse psychologique.
   - L'utilisateur n'est pas bloqué : il peut cliquer sur *« Je comprends, continuer quand même »*.

2. **Avertissement permanent** :
   - Présent sur l'écran d'accueil et sur chaque résultat :
     > *« Cette suggestion est une orientation générale, pas un diagnostic. Elle ne remplace pas l'avis d'un médecin. En cas d'urgence, appelez le 190. »*

3. **Protection des Données Personnelles** :
   - Seul le texte des symptômes et la liste des spécialités sont transmis à Gemini.
   - **Aucun nom, e-mail, téléphone, antécédent, allergie ni donnée de profil** n'est transmis.
   - Recueil préalable du consentement mémorisé dans `SharedPreferences`.

4. **Résilience & Mode Dégradé Hors-ligne** :
   - En cas d'absence de réseau, de quota dépassé (429) ou de clé non configurée, un moteur local de correspondance par mots-clés prend le relais (ex: *« peau, bouton »* → Dermatologie, *« dent, carie »* → Dentiste, *« vue, lunettes »* → Ophtalmologie).
   - L'utilisateur est explicitement informé que la suggestion provient du mode local de secours.

---

### 💾 Base de Données SQLite (Migration Version 5)

La migration en version 5 dans `DatabaseHelper` ajoute deux tables dédiées de manière non-destructive :

1. **`specialties`** : Répertoire officiel des spécialités médicales disponibles (initialisé avec 15 spécialités majeures).
2. **`orientation_history`** : Historique local des orientations du patient (date, texte, spécialités suggérées, urgence, conseil).
   - L'utilisateur peut consulter ses précédentes orientations ou utiliser le bouton **« Tout effacer »** à tout moment.

---

## 🚀 Navigation & Accès

- **Routes GoRouter** :
  - `/appointments/orientation` (nom: `appointments-orientation`)
  - `/appointments/orientation/history` (nom: `appointments-orientation-history`)
  - `/appointments/nearby` (supporte le passage de la spécialité en paramètre `extra`)
  - `/appointments/book` (supporte le pré-remplissage via le paramètre `extra: doctor`)
- **Points d'entrée dans l'application** :
  1. **Tableau de bord Rendez-vous (Onglet Médecins)** : Bannière interactive *« Quelle spécialité consulter ? »*.
  2. **Formulaire de prise de rendez-vous** : Lien d'assistance *« Quelle spécialité consulter ? Se faire orienter par l'IA »*.
  3. **Recherche à proximité** : Redirection directe depuis une spécialité sans médecin dans le carnet.

---

## 🧪 Tests & Qualité de code

Le module dispose de suites de tests unitaires et d'intégration complètes (100% de réussite) :

```bash
# Lancer les tests d'orientation médicale
flutter test test/features/appointments/orientation/

# Lancer tous les tests du module appointments (CRUD + Navigation + Nearby + Orientation)
flutter test test/appointments_crud_test.dart test/appointments_navigation_test.dart test/features/appointments/nearby/ test/features/appointments/orientation/
```

### Couverture des tests `orientation` :
- `emergency_detector_test.dart` : Détection multi-langues (FR, EN, AR), insensibilité aux accents, non-déclenchement sur symptômes bénins.
- `orientation_result_test.dart` : Parsing JSON strict, champs optionnels, validation des niveaux d'urgence.
- `gemini_service_test.dart` : Mock HTTP (Mocktail), gestion des erreurs 401/403, 429, 500, timeouts, retries et blocages de sécurité.
- `orientation_repository_test.dart` : Intégration SQLite en mémoire (`sqflite_common_ffi`), validation et canonicalisation des spécialités, association aux médecins du carnet, mode dégradé hors-ligne et gestion d'historique.

