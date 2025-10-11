# 📖 القرآن الكريم - Al-Quran App

Une application mobile moderne et élégante pour lire le Saint Coran avec une expérience utilisateur fluide et respectueuse.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![Material Design 3](https://img.shields.io/badge/Material_3-Yes-757575?logo=material-design)

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
- Liste complète des 114 Sourates
- Section "Reprendre la lecture" mise en évidence
- Barre de recherche moderne avec animations
- Cards élégantes avec effets hover
- Badge "En cours" pour la dernière Sourate lue

#### Détail Sourate
- Header avec dégradé et informations complètes
- Lecteur audio intégré et minimaliste
- Affichage des versets avec :
  - Texte arabe (police Cairo, taille optimale)
  - Traduction française
  - Numérotation claire
  - Actions (lecture, favoris, partage)
- Player flottant lors du scroll
- Navigation fluide avec animations

#### Widgets réutilisables
- `SurahCard` : Card animée pour chaque Sourate
- `AudioPlayerWidget` : Lecteur audio complet avec contrôles
- `CustomSearchBar` : Barre de recherche avec animations
- `ShimmerLoading` : Effet de chargement avec couleur or

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

```
lib/
├── main.dart                    # Point d'entrée avec configuration
├── models/
│   └── surah.dart              # Modèle de données Surah
├── screens/
│   ├── main_navigation.dart    # Navigation principale avec BottomNav
│   ├── home_screen.dart        # Écran d'accueil (liste des Sourates)
│   └── surah_detail_screen.dart # Détail d'une Sourate
├── theme/
│   ├── app_colors.dart         # Palette de couleurs complète
│   └── app_theme.dart          # Thèmes Light & Dark
└── widgets/
    ├── audio_player_widget.dart # Lecteur audio
    ├── custom_search_bar.dart   # Barre de recherche
    ├── shimmer_loading.dart     # Effet de chargement
    └── surah_card.dart          # Card de Sourate
```

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

## 📦 Dépendances

```yaml
dependencies:
  google_fonts: ^6.1.0          # Polices Cairo et Poppins
  just_audio: ^0.9.36           # Lecteur audio
  provider: ^6.1.1              # State management
  http: ^1.1.2                  # Requêtes HTTP
  animations: ^2.0.11           # Animations avancées
  flutter_vibrate: ^1.3.0       # Feedback haptique
```

## 🎯 État actuel

### ✅ Implémenté
- [x] Système de thème complet (Light + Dark)
- [x] Charte graphique islamique
- [x] Écran d'accueil avec liste des Sourates
- [x] Écran de détail Sourate
- [x] Lecteur audio avec contrôles
- [x] Animations et transitions fluides
- [x] Barre de recherche fonctionnelle
- [x] Bottom navigation
- [x] Feedback haptique
- [x] Loading states avec shimmer

### 🚧 À venir
- [ ] Intégration API Quran réelle
- [ ] Lecture audio fonctionnelle
- [ ] Sauvegarde des favoris
- [ ] Historique de lecture
- [ ] Traductions multiples
- [ ] Mode nuit automatique
- [ ] Partage de versets
- [ ] Notifications pour rappels

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

## 📝 License

Ce projet est sous licence MIT - voir le fichier LICENSE pour plus de détails.

## 👨‍💻 Auteur

Développé avec ❤️ et respect pour le Saint Coran.

## 🙏 Remerciements

- Polices Google Fonts (Cairo, Poppins)
- API Quran (à intégrer)
- Communauté Flutter

---

**Note** : Cette application est développée dans un esprit de respect et d'humilité envers le Saint Coran. Toute suggestion d'amélioration est appréciée.
