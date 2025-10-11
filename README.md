# 📖 القرآن الكريم - Al-Quran App

Une application mobile moderne et élégante pour lire le Saint Coran avec une expérience utilisateur fluide et respectueuse.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![Material Design 3](https://img.shields.io/badge/Material_3-Yes-757575?logo=material-design)
![Riverpod](https://img.shields.io/badge/Riverpod-2.x-00D9FF)
![API](https://img.shields.io/badge/API-Al--Quran_Cloud-4CAF50)

## 🌟 Points forts

- ✅ **100% Fonctionnel** : API réelle intégrée avec cache intelligent
- 🎵 **Lecteur audio complet** : Lecture verset par verset avec auto-scroll
- 🌍 **Traduction française** : Traduction de Muhammad Hamidullah
- 🎨 **Design islamique** : Interface élégante et respectueuse
- 📱 **Mode hors ligne** : Fonctionne même sans connexion Internet
- 🎯 **Open Source** : Code propre et bien documenté

## ✨ Caractéristiques

### 🎨 Design & UI/UX
- **Charte graphique islamique** avec couleurs inspirées de l'art islamique
  - Bleu nuit profond (#1F4788)
  - Or luxueux (#D4AF37)
  - Bronze doux (#CD7F32)
- **Dark Mode** complet avec palette adaptée
- **Typographie respectueuse**
  - Cairo pour le texte arabe
  - Poppins pour le texte latin
- **Animations fluides** (300ms transitions)
- **Micro-interactions** avec feedback haptique

### 📱 Fonctionnalités

#### Écran d'accueil
****- Liste complète des 114 Sourates depuis l'API Al-Quran Cloud
- Section "Reprendre la lecture" avec position sauvegardée
- Barre de recherche moderne avec animations
- Cards élégantes avec effets hover
- Badge "En cours" pour la dernière Sourate lue
- Gestion de la connectivité avec banner d'avertissement

#### Détail Sourate
- Header avec dégradé et informations complètes
- **Lecteur audio fonctionnel** avec :
  - Lecture verset par verset
  - Contrôles complets (play, pause, suivant, précédent)
  - Barre de progression interactive
  - Sélection de récitateur
  - Auto-scroll vers le verset en cours
  - Mini-player flottant lors du scroll
- **Toggle traduction** : Basculer entre vue Coran seul et vue avec traduction
- Affichage des versets avec :
  - Texte arabe (police Cairo, taille optimale)
  - Traduction française (Muhammad Hamidullah)
  - Numérotation claire avec badges dorés
  - Highlight du verset en cours de lecture
  - Actions (lecture, favoris, partage)
- Bismillah stylisé (sauf pour Sourate 9)
- Navigation fluide avec animations

#### Widgets réutilisables
- `SurahCard` : Card animée pour chaque Sourate
- `FullSurahAudioPlayer` : Lecteur audio complet avec playlist
- `MiniAudioPlayer` : Mini-player persistant
- `AudioPlayerController` : Contrôles audio réutilisables
- `ReciterSelector` : Sélecteur de récitateur
- `TranslationSelector` : Sélecteur de traduction
- `CustomSearchBar` : Barre de recherche avec animations
- `ShimmerLoading` : Effet de chargement avec couleur or
- `ConnectivityBanner` : Banner de statut de connexion

### 🎭 Animations & Transitions
- Fade + Slide pour les transitions de pages
- Shimmer loading avec teinte dorée
- Scale animation sur les interactions (1.02x)
- Pulse animation pour le bouton play
- Transitions fluides entre écrans

### ♿ Accessibilité
- Contraste WCAG AA respecté
- Touch targets minimum 48x48dp
- Support du mode système (dark/light)
- Animations désactivables si besoin
- Texte redimensionnable

## 🏗️ Architecture

L'application suit une architecture propre et modulaire avec séparation des responsabilités :

```
lib/
├── main.dart                           # Point d'entrée avec configuration
├── core/
│   └── exceptions/
│       └── api_exceptions.dart         # Exceptions personnalisées
├── models/
│   ├── surah.dart                      # Modèle Surah (legacy)
│   └── quran_models.dart               # Modèles API (Surah, Ayah, Edition, etc.)
├── providers/
│   ├── quran_providers.dart            # Providers Riverpod pour le Quran
│   └── audio_providers.dart            # Providers pour l'audio
├── screens/
│   ├── main_navigation.dart            # Navigation principale avec BottomNav
│   ├── home_screen.dart                # Écran d'accueil (liste des Sourates)
│   └── surah_detail_screen.dart        # Détail d'une Sourate avec audio et traduction
├── services/
│   ├── quran_api_service.dart          # Service API Al-Quran Cloud
│   ├── audio_service.dart              # Service de lecture audio
│   ├── audio_playlist_service.dart     # Gestion des playlists audio
│   ├── cache_service.dart              # Service de cache avec Hive
│   └── connectivity_service.dart       # Gestion de la connectivité
├── theme/
│   ├── app_colors.dart                 # Palette de couleurs complète
│   └── app_theme.dart                  # Thèmes Light & Dark
├── utils/
│   ├── available_translations.dart     # Traductions disponibles
│   └── surah_adapter.dart              # Adaptateurs de modèles
└── widgets/
    ├── audio_player_widget.dart        # Lecteur audio basique
    ├── full_surah_audio_player.dart    # Lecteur audio complet avec playlist
    ├── mini_audio_player.dart          # Mini-player persistant
    ├── audio_player_controller.dart    # Contrôles audio réutilisables
    ├── reciter_selector.dart           # Sélecteur de récitateur
    ├── translation_selector.dart       # Sélecteur de traduction
    ├── connectivity_banner.dart        # Banner de connectivité
    ├── custom_search_bar.dart          # Barre de recherche
    ├── shimmer_loading.dart            # Effet de chargement
    └── surah_card.dart                 # Card de Sourate
```

### Pattern architectural
- **State Management** : Riverpod pour une gestion d'état réactive et performante
- **Services** : Couche de services pour l'API, l'audio et le cache
- **Cache** : Hive pour le stockage local avec stratégie de cache intelligent
- **API** : Dio avec retry automatique et gestion d'erreurs centralisée

## 🚀 Installation

### Prérequis
- Flutter SDK 3.9.2 ou supérieur
- Dart 3.x
- Android Studio / Xcode pour les émulateurs

### Étapes

1. **Cloner le repository** (si applicable)
```bash
git clone [votre-repo]
cd alquran
```

2. **Installer les dépendances**
```bash
flutter pub get
```

3. **Lancer l'application**
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# Web
flutter run -d chrome
```

## 📱 Comment utiliser

### Navigation
1. **Écran d'accueil** : Parcourez la liste des 114 Sourates
   - Utilisez la barre de recherche pour trouver une Sourate
   - La section "Reprendre la lecture" affiche votre dernière lecture
   - Tapez sur une carte pour ouvrir la Sourate

2. **Page Sourate** : Lisez et écoutez le Coran
   - **Toggle traduction** : Tapez l'icône de traduction dans l'en-tête pour afficher/masquer la traduction
   - **Lecteur audio** : Tapez Play pour commencer la lecture verset par verset
   - **Contrôles** : Utilisez les boutons suivant/précédent pour naviguer
   - **Récitateur** : Changez de récitateur en tapant sur l'icône micro
   - **Auto-scroll** : Le texte défile automatiquement vers le verset en cours

### Fonctionnalités clés
- 🎵 **Lecture audio** : Écoutez verset par verset avec highlight automatique
- 🔄 **Toggle traduction** : Basculez entre vue arabe seule et vue avec traduction
- 📱 **Mode hors ligne** : Les Sourates consultées restent en cache
- 🌙 **Mode sombre** : Active automatiquement selon vos préférences système
- 🔖 **Position sauvegardée** : Reprenez là où vous vous êtes arrêté

## 📦 Dépendances

### Principales
```yaml
dependencies:
  # State Management
  flutter_riverpod: ^2.6.1      # State management réactif et performant
  
  # API & Network
  dio: ^5.7.0                    # Client HTTP avancé
  dio_smart_retry: ^6.0.0        # Retry automatique pour Dio
  connectivity_plus: ^5.0.2      # Détection de connectivité
  
  # Audio
  just_audio: ^0.9.46            # Lecteur audio avec support streaming
  audio_session: ^0.1.25         # Gestion des sessions audio
  
  # Cache & Storage
  hive: ^2.2.3                   # Base de données NoSQL locale
  hive_flutter: ^1.1.0           # Support Flutter pour Hive
  path_provider: ^2.1.1          # Accès aux dossiers système
  
  # UI & Design
  google_fonts: ^6.2.1           # Polices Cairo et Poppins
  flutter_vibrate: ^1.3.0        # Feedback haptique
  
  # Utils
  intl: ^0.19.0                  # Internationalisation
```

### Dev Dependencies
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0          # Linting strict
  hive_generator: ^2.0.1         # Générateur de code pour Hive
  build_runner: ^2.4.6           # Générateur de code
```

## 🎯 État actuel

### ✅ Implémenté
- [x] **Système de thème complet** (Light + Dark)
- [x] **Charte graphique islamique** avec couleurs respectueuses
- [x] **Intégration API Al-Quran Cloud** avec cache intelligent
- [x] **Écran d'accueil** avec liste des 114 Sourates
- [x] **Écran de détail Sourate** avec animations
- [x] **Lecteur audio fonctionnel** avec :
  - [x] Lecture verset par verset
  - [x] Contrôles complets (play, pause, suivant, précédent)
  - [x] Playlist automatique
  - [x] Sélection de récitateurs
  - [x] Mini-player persistant
  - [x] Auto-scroll vers le verset en cours
- [x] **Traduction française** (Muhammad Hamidullah)
- [x] **Toggle traduction** pour afficher/masquer les traductions
- [x] **Gestion de la connectivité** avec détection hors ligne
- [x] **Cache système** avec Hive (7 jours pour contenu statique, 1h pour audio)
- [x] **Animations et transitions fluides**
- [x] **Barre de recherche** fonctionnelle
- [x] **Bottom navigation**
- [x] **Feedback haptique**
- [x] **Loading states** avec shimmer doré
- [x] **Sauvegarde de la position de lecture**
- [x] **Gestion d'erreurs** robuste avec fallback sur cache

### 🚧 Prochaines fonctionnalités
- [ ] **Favoris** : Marquer des versets comme favoris
- [ ] **Recherche avancée** : Rechercher dans les versets et traductions
- [ ] **Traductions multiples** : Basculer entre plusieurs traductions
- [ ] **Thème personnalisable** : Taille de police ajustable
- [ ] **Mode lecture** : Mode immersif sans distractions
- [ ] **Partage de versets** : Partager des versets avec image
- [ ] **Notes personnelles** : Ajouter des notes aux versets
- [ ] **Notifications** : Rappels de lecture
- [ ] **Mode nuit automatique** : Basculer selon l'heure
- [ ] **Statistiques** : Temps de lecture, progression
- [ ] **Bookmarks** : Marque-pages multiples

### 🎯 API utilisée
- **Al-Quran Cloud** : https://api.alquran.cloud/v1
  - Texte arabe complet (édition Madinah)
  - Traductions dans plusieurs langues
  - Audio de multiples récitateurs
  - Métadonnées complètes (révélation, nombre de versets, etc.)

## 📝 License

Ce projet est sous licence MIT - voir le fichier LICENSE pour plus de détails.

## 🎨 Charte graphique détaillée

### Couleurs principales
| Nom        | Hex       | Usage             |
| ---------- | --------- | ----------------- |
| Bleu nuit  | `#1F4788` | Primaire, Headers |
| Or luxueux | `#D4AF37` | Accents, CTA      |
| Bronze     | `#CD7F32` | Secondaire        |
| Ivoire     | `#FFFFF0` | Background Light  |
| Dark BG    | `#0F1419` | Background Dark   |

### Typographie
- **Cairo** : Texte arabe (600-700 weight)
- **Poppins** : Texte latin (400-700 weight)

### Espacements
- Small: 8dp
- Medium: 16dp
- Large: 24dp
- XLarge: 32dp

### Radius
- Small: 8dp
- Medium: 16dp
- Large: 24dp

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## 👨‍💻 Auteur

Développé avec ❤️ et respect pour le Saint Coran.

## 🙏 Remerciements

- **Al-Quran Cloud API** : Pour l'API gratuite et complète
- **Google Fonts** : Polices Cairo et Poppins
- **just_audio** : Excellent lecteur audio Flutter
- **Riverpod** : State management élégant et performant
- **Communauté Flutter** : Pour les packages et le support

---

**Note** : Cette application est développée dans un esprit de respect et d'humilité envers le Saint Coran. Toute suggestion d'amélioration est la bienvenue pour rendre cette application plus utile à la communauté musulmane.
