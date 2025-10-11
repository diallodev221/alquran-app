# 🏗️ Architecture de l'Application Al-Quran

## 📁 Structure Complète du Projet

```
alquran/
│
├── 📱 lib/                              # Code source principal
│   │
│   ├── 🚀 main.dart                     # Point d'entrée de l'application
│   │   ├── Configuration système UI
│   │   ├── Initialisation Google Fonts
│   │   └── Setup thèmes Light/Dark
│   │
│   ├── 📊 models/                       # Modèles de données
│   │   └── surah.dart
│   │       ├── class Surah              # Modèle principal
│   │       ├── fromJson / toJson        # Sérialisation
│   │       └── demoSurahs[]             # 10 sourates de démo
│   │
│   ├── 🖼️ screens/                      # Écrans de l'application
│   │   │
│   │   ├── main_navigation.dart         # Navigation principale
│   │   │   ├── Bottom Navigation Bar
│   │   │   ├── 4 onglets (Quran, Favoris, Recherche, Paramètres)
│   │   │   ├── Gestion des transitions
│   │   │   └── Feedback haptique
│   │   │
│   │   ├── home_screen.dart             # Écran d'accueil
│   │   │   ├── SliverAppBar avec gradient
│   │   │   ├── Barre de recherche
│   │   │   ├── Section "Reprendre la lecture"
│   │   │   ├── Liste des Sourates
│   │   │   ├── Shimmer loading
│   │   │   └── Navigation vers détail
│   │   │
│   │   └── surah_detail_screen.dart     # Détail d'une Sourate
│   │       ├── Header expansible
│   │       ├── Lecteur audio principal
│   │       ├── Bismillah stylisé
│   │       ├── Liste des versets
│   │       ├── Actions par verset
│   │       └── Lecteur flottant
│   │
│   ├── 🎨 theme/                        # Système de thème
│   │   │
│   │   ├── app_colors.dart              # Palette de couleurs
│   │   │   ├── Couleurs Light Mode
│   │   │   ├── Couleurs Dark Mode
│   │   │   ├── Dégradés
│   │   │   └── Ombres (shadows)
│   │   │
│   │   └── app_theme.dart               # Configuration des thèmes
│   │       ├── lightTheme()
│   │       ├── darkTheme()
│   │       ├── Constants (animations, spacing, radius)
│   │       └── Widget themes (Card, Button, Input, etc.)
│   │
│   └── 🧩 widgets/                      # Composants réutilisables
│       │
│       ├── surah_card.dart              # Card de Sourate
│       │   ├── Animation scale au tap
│       │   ├── Shadow dynamique
│       │   ├── Badge "En cours"
│       │   └── Infos complètes
│       │
│       ├── audio_player_widget.dart     # Lecteur audio
│       │   ├── Contrôles complets
│       │   ├── Barre de progression
│       │   ├── Bouton play avec pulse
│       │   └── Options avancées
│       │
│       ├── custom_search_bar.dart       # Barre de recherche
│       │   ├── Animation focus
│       │   ├── Clear button
│       │   └── Scale effect
│       │
│       └── shimmer_loading.dart         # Effet de chargement
│           ├── ShimmerLoading (generic)
│           └── SurahCardShimmer
│
├── 📋 pubspec.yaml                      # Dépendances du projet
│   ├── google_fonts: ^6.1.0
│   ├── just_audio: ^0.9.36
│   ├── provider: ^6.1.1
│   ├── http: ^1.1.2
│   ├── animations: ^2.0.11
│   └── flutter_vibrate: ^1.3.0
│
├── 📚 Documentation/
│   ├── README.md                        # Documentation principale
│   ├── GUIDE_DEMARRAGE.md              # Guide de démarrage
│   ├── FEATURES.md                      # Fonctionnalités détaillées
│   ├── RESUME.md                        # Résumé simple
│   └── ARCHITECTURE.md                  # Ce fichier
│
├── 🤖 android/                          # Configuration Android
├── 🍎 ios/                              # Configuration iOS
└── 🧪 test/                             # Tests unitaires

```

## 🔄 Flux de Navigation

```
┌─────────────────────────────────────────────────────┐
│                   Main App                          │
│              (MaterialApp)                          │
│   ┌─────────────────────────────────────────┐      │
│   │     Theme System                        │      │
│   │  ├─ Light Theme (Bleu/Or)              │      │
│   │  └─ Dark Theme (Noir/Or)               │      │
│   └─────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│           MainNavigation                            │
│         (Bottom Navigation)                         │
│   ┌──────────┬──────────┬──────────┬──────────┐   │
│   │  Quran   │ Favoris  │Recherche │Paramètres│   │
│   └──────────┴──────────┴──────────┴──────────┘   │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│              HomeScreen                             │
│  ┌─────────────────────────────────────────────┐   │
│  │ Header (Gradient bleu-or)                   │   │
│  │ └─ Titre: القرآن الكريم                     │   │
│  ├─────────────────────────────────────────────┤   │
│  │ CustomSearchBar                             │   │
│  ├─────────────────────────────────────────────┤   │
│  │ "Reprendre la lecture" (si applicable)      │   │
│  ├─────────────────────────────────────────────┤   │
│  │ Liste des Sourates                          │   │
│  │  ├─ SurahCard #1                           │   │
│  │  ├─ SurahCard #2                           │   │
│  │  └─ ...                                     │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
        ↓ (Tap sur une Sourate)
┌─────────────────────────────────────────────────────┐
│           SurahDetailScreen                         │
│  ┌─────────────────────────────────────────────┐   │
│  │ Header Expansible                           │   │
│  │  ├─ Nom arabe (48px)                       │   │
│  │  ├─ Nom français                            │   │
│  │  └─ Infos (Meccan/Medinan, Ayahs)         │   │
│  ├─────────────────────────────────────────────┤   │
│  │ AudioPlayerWidget                           │   │
│  │  ├─ Contrôles (prev, -10, play, +10, next)│   │
│  │  ├─ Progress bar                            │   │
│  │  └─ Options (repeat, speed, bookmark)      │   │
│  ├─────────────────────────────────────────────┤   │
│  │ Bismillah (stylisé)                        │   │
│  ├─────────────────────────────────────────────┤   │
│  │ Liste des Versets                           │   │
│  │  ├─ Ayah #1 (arabe + traduction)          │   │
│  │  ├─ Ayah #2                                │   │
│  │  └─ ...                                     │   │
│  └─────────────────────────────────────────────┘   │
│                                                     │
│  [Lecteur flottant si scroll > 300px]             │
└─────────────────────────────────────────────────────┘
```

## 🎨 Système de Thème

```
AppTheme
│
├── lightTheme()
│   ├── ColorScheme
│   │   ├── primary: deepBlue (#1F4788)
│   │   ├── secondary: luxuryGold (#D4AF37)
│   │   ├── tertiary: softBronze
│   │   ├── surface: white
│   │   └── background: ivory
│   │
│   ├── TextTheme (Poppins)
│   │   ├── displayLarge (32px, bold)
│   │   ├── displayMedium (28px, bold)
│   │   ├── titleLarge (18px, w600)
│   │   ├── bodyLarge (16px)
│   │   └── bodyMedium (14px)
│   │
│   ├── ComponentThemes
│   │   ├── AppBarTheme (transparent, centered)
│   │   ├── CardTheme (radius 16, no elevation)
│   │   ├── ElevatedButtonTheme (deepBlue, radius 16)
│   │   ├── InputDecorationTheme (filled, radius 16)
│   │   └── BottomNavBarTheme (white, selected blue)
│   │
│   └── Constants
│       ├── animationDuration: 300ms
│       ├── radiusMedium: 16dp
│       └── paddingMedium: 16dp
│
└── darkTheme()
    ├── ColorScheme
    │   ├── primary: lightBlue
    │   ├── secondary: luxuryGold (constant)
    │   ├── surface: darkCard (#212B3D)
    │   └── background: darkBackground (#0F1419)
    │
    └── ... (structure identique au light)
```

## 🔧 Widgets Réutilisables

### SurahCard
```dart
Props:
  - surah: Surah
  - onTap: () → void
  - isLastRead: bool

Structure:
  Container (avec shadow)
    ├─ Badge "En cours" (si isLastRead)
    ├─ Row
    │   ├─ Numéro (cercle avec gradient)
    │   ├─ Column
    │   │   ├─ Nom français
    │   │   └─ Row (badge + nombre ayahs)
    │   └─ Nom arabe (Cairo)

Animations:
  - Scale 1.0 → 1.02 au tap
  - Shadow 8 → 16 au hover
```

### AudioPlayerWidget
```dart
Props:
  - surahName: String
  - currentAyah: int
  - totalAyahs: int

Structure:
  Container (gradient bleu)
    ├─ Header (icône + titre + menu)
    ├─ Slider (progress bar)
    ├─ Row (temps actuel / total)
    ├─ Contrôles
    │   ├─ Previous
    │   ├─ -10s
    │   ├─ Play/Pause (avec pulse)
    │   ├─ +10s
    │   └─ Next
    └─ Options (repeat, speed, bookmark)

Animations:
  - Pulse 1.0 → 1.1 sur play button
  - Repeat avec reverse
```

### CustomSearchBar
```dart
Props:
  - onSearch: (String) → void
  - hintText: String

Structure:
  Container
    └─ TextField
        ├─ prefixIcon: search
        └─ suffixIcon: clear (si texte)

Animations:
  - Scale 1.0 → 1.02 au focus
  - Border color: transparent → gold
  - Shadow: normal → goldGlow
```

### ShimmerLoading
```dart
Props:
  - width: double
  - height: double
  - borderRadius: BorderRadius?

Animation:
  Gradient qui se déplace -1.0 → 2.0
  Duration: 1500ms
  Colors: paleGold → luxuryGold → paleGold
```

## 📊 Modèle de Données

```dart
class Surah {
  int number;              // 1-114
  String name;             // "Al-Fatiha"
  String arabicName;       // "الفاتحة"
  String englishName;      // "The Opening"
  String revelationType;   // "Meccan" / "Medinan"
  int numberOfAyahs;       // Nombre de versets
  String meaning;          // Signification
  
  // Méthodes
  fromJson(Map<String, dynamic>)
  toJson() → Map<String, dynamic>
}

// Actuellement: 10 sourates de démo
demoSurahs = [
  Al-Fatiha (1),
  Al-Baqarah (2),
  Aal-E-Imran (3),
  An-Nisa (4),
  Al-Maidah (5),
  Al-Anam (6),
  Al-Araf (7),
  Al-Anfal (8),
  At-Tawbah (9),
  Yunus (10)
]
```

## 🎯 État Management (Actuel)

```
Actuellement: StatefulWidget (local state)

Structure:
  HomeScreen
    ├─ _isLoading: bool
    ├─ _surahs: List<Surah>
    ├─ _filteredSurahs: List<Surah>
    └─ _lastReadSurahNumber: int

  SurahDetailScreen
    ├─ _showFloatingPlayer: bool
    ├─ _ayahs: List<Map>
    └─ ScrollController

  MainNavigation
    ├─ _currentIndex: int
    └─ AnimationController

Future: Provider / Riverpod pour state global
  - Favoris
  - Historique
  - Paramètres
  - Audio state
```

## 🔄 Cycle de Vie

### Au Démarrage (main.dart)
```
1. WidgetsFlutterBinding.ensureInitialized()
2. SystemChrome configuration (UI system)
3. Lancement AlQuranApp
4. Chargement thèmes (light/dark)
5. GoogleFonts preload
6. Navigation vers MainNavigation
```

### Sur HomeScreen
```
1. initState()
   ├─ Setup AnimationController
   └─ _loadSurahs() async
       ├─ Simule chargement (1.5s)
       ├─ Charge demoSurahs
       └─ setState + forward animation

2. build()
   ├─ CustomScrollView
   ├─ SliverAppBar (header)
   ├─ SearchBar
   ├─ "Reprendre" card (si applicable)
   └─ SliverList (Sourates)

3. Navigation
   ├─ Tap → _navigateToSurah()
   └─ PageRouteBuilder (slide + fade)
```

### Sur SurahDetailScreen
```
1. initState()
   ├─ Setup AnimationController
   ├─ ScrollController listener
   └─ Forward animation

2. build()
   ├─ SliverAppBar expansible
   ├─ AudioPlayerWidget
   ├─ Bismillah (si applicable)
   └─ SliverList (versets)

3. Scroll
   ├─ offset > 300px
   └─ Show floating player

4. Dispose
   ├─ AnimationController.dispose()
   └─ ScrollController.dispose()
```

## 🎨 Animations Timing

```
Type                  Duration    Curve           Usage
──────────────────────────────────────────────────────────
Page Transition       300ms       easeInOut       Navigation
Button Tap            150ms       easeInOut       Interactions
Shimmer Loop          1500ms      easeInOutSine   Loading
Play Pulse            800ms       easeInOut       Audio button
Scale Effect          150ms       easeInOut       Cards
Fade In               300ms       easeInOut       Content
```

## 📦 Dépendances Détaillées

```yaml
google_fonts: ^6.1.0
  ↳ Usage: Poppins (UI) + Cairo (arabe)
  ↳ Files: 30 fichiers
  
just_audio: ^0.9.36
  ↳ Usage: Audio player (structure prête)
  ↳ Platform: iOS, Android, Web
  
provider: ^6.1.1
  ↳ Usage: State management (futur)
  ↳ Pattern: Provider/Consumer
  
http: ^1.1.2
  ↳ Usage: API calls (futur)
  ↳ Target: Quran API
  
animations: ^2.0.11
  ↳ Usage: Transitions avancées
  ↳ Type: SharedAxis, FadeThrough
  
flutter_vibrate: ^1.3.0
  ↳ Usage: Haptic feedback
  ↳ Platform: iOS, Android
```

## 🚀 Performance

### Optimisations Actuelles
```
✅ Lazy loading des widgets
✅ const constructors partout
✅ AnimationController dispose
✅ ScrollController dispose
✅ Cached images (futures assets)
✅ Shimmer pendant loading
```

### Métriques Cibles
```
FPS:              60 (garanti)
Time to First Paint:  < 1s
Navigation:       < 300ms
Search:           < 100ms
Memory:           < 150MB
```

## 🎯 Prochaines Étapes Techniques

### Phase 1: API Integration
```
1. Créer service/quran_api.dart
2. Implémenter fetchAllSurahs()
3. Implémenter fetchSurahDetail(int)
4. Cache les données (shared_preferences)
```

### Phase 2: Audio
```
1. Connecter just_audio
2. Charger URLs récitateurs
3. Gérer states (playing, paused, etc.)
4. Background playback
```

### Phase 3: Persistance
```
1. Ajouter hive ou sqflite
2. Sauvegarder favoris
3. Historique de lecture
4. Paramètres utilisateur
```

---

## 📚 Ressources

- **Flutter Docs**: https://docs.flutter.dev
- **Material 3**: https://m3.material.io
- **Google Fonts**: https://fonts.google.com
- **Al-Quran API**: https://alquran.cloud/api

---

**Cette architecture est conçue pour être:**
- ✅ **Scalable** : Facile d'ajouter des features
- ✅ **Maintenable** : Code propre et organisé
- ✅ **Performante** : Optimisée pour 60fps
- ✅ **Testable** : Séparation des responsabilités

🚀 **L'application est prête pour le développement !**

