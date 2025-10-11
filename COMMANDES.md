# 🛠️ Commandes Utiles - Al-Quran App

## 🚀 Commandes de Base

### Lancer l'Application
```bash
# Appareil par défaut
flutter run

# iOS Simulator
flutter run -d ios

# Android Emulator
flutter run -d android

# Chrome
flutter run -d chrome

# Appareil spécifique (voir flutter devices)
flutter run -d "iPhone 15"
```

### Voir les Appareils
```bash
flutter devices
```

---

## 🧹 Nettoyage & Maintenance

### Nettoyer le Projet
```bash
# Nettoyer les builds
flutter clean

# Réinstaller les dépendances
flutter pub get

# Nettoyage complet
flutter clean && flutter pub get
```

### Mettre à Jour les Dépendances
```bash
# Voir les packages obsolètes
flutter pub outdated

# Mettre à jour (safe)
flutter pub upgrade

# Mettre à jour (major versions)
flutter pub upgrade --major-versions
```

---

## 🔍 Analyse & Tests

### Analyser le Code
```bash
# Analyse statique
flutter analyze

# Avec détails
flutter analyze --verbose
```

### Formatter le Code
```bash
# Formater tout le projet
dart format lib/

# Vérifier sans modifier
dart format --output=none lib/
```

### Linter
```bash
# Avec le plugin IDE ou
flutter analyze
```

---

## 🏗️ Build & Release

### Mode Debug
```bash
# Android APK
flutter build apk --debug

# iOS
flutter build ios --debug
```

### Mode Release
```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (App Store)
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

---

## 📊 Performance & Debug

### Profiler
```bash
# Mode profile
flutter run --profile

# Ouvrir DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

### Taille de l'App
```bash
# Analyser la taille
flutter build apk --analyze-size
flutter build appbundle --analyze-size
```

### Performances
```bash
# Activer le performance overlay
# Pendant l'exécution, appuyez sur 'P'

# Ou
flutter run --enable-software-rendering
```

---

## 🎨 Assets & Icons

### Générer les Icons (futur)
```bash
# Installer flutter_launcher_icons
flutter pub add dev:flutter_launcher_icons

# Générer
flutter pub run flutter_launcher_icons:main
```

### Générer Splash Screen (futur)
```bash
# Installer flutter_native_splash
flutter pub add dev:flutter_native_splash

# Générer
flutter pub run flutter_native_splash:create
```

---

## 🔧 Configuration

### Voir la Configuration Flutter
```bash
flutter doctor
flutter doctor -v
```

### Voir les Variables d'Environnement
```bash
flutter config
```

### Activer/Désactiver Plateformes
```bash
# Web
flutter config --enable-web

# macOS Desktop
flutter config --enable-macos-desktop

# Windows Desktop
flutter config --enable-windows-desktop
```

---

## 📱 iOS Spécifique

### Pod Install
```bash
cd ios
pod install
cd ..
```

### Nettoyer Build iOS
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
```

### Ouvrir dans Xcode
```bash
open ios/Runner.xcworkspace
```

---

## 🤖 Android Spécifique

### Gradle Clean
```bash
cd android
./gradlew clean
cd ..
```

### Voir les Devices Android
```bash
adb devices
```

### Logcat
```bash
adb logcat | grep flutter
```

### Ouvrir dans Android Studio
```bash
open -a "Android Studio" android/
```

---

## 🌐 Web Spécifique

### Lancer avec Port Spécifique
```bash
flutter run -d chrome --web-port=8080
```

### Build Web Optimisé
```bash
flutter build web --release --web-renderer canvaskit
```

---

## 🐛 Debug

### Hot Reload & Restart
```bash
# Pendant l'exécution
r  # Hot reload
R  # Hot restart
p  # Toggle performance overlay
q  # Quit
```

### Logs
```bash
# Verbose logs
flutter run -v

# Très verbose
flutter run -vv
```

### Stack Traces
```bash
# Traces complètes
flutter run --verbose
```

---

## 📦 Dépendances

### Ajouter une Dépendance
```bash
flutter pub add package_name

# Dev dependency
flutter pub add dev:package_name
```

### Supprimer une Dépendance
```bash
flutter pub remove package_name
```

### Voir les Dépendances
```bash
flutter pub deps
```

---

## 🎯 Raccourcis Pratiques

### Créer un Nouveau Widget
```bash
# Copier un widget existant comme template
cp lib/widgets/surah_card.dart lib/widgets/my_new_widget.dart
```

### Chercher dans le Code
```bash
# macOS/Linux
grep -r "SurahCard" lib/

# Avec contexte
grep -rn "SurahCard" lib/
```

### Compter les Lignes de Code
```bash
find lib -name "*.dart" | xargs wc -l
```

---

## 🔍 Commandes Git Utiles

### Status & Commit
```bash
git status
git add .
git commit -m "✨ Add new feature"
git push
```

### Branches
```bash
# Créer une branche
git checkout -b feature/nouvelle-fonctionnalite

# Changer de branche
git checkout main

# Lister les branches
git branch -a
```

---

## 📚 Documentation

### Générer la Doc
```bash
dart doc .
```

### Ouvrir la Doc Flutter
```bash
# Online
open https://docs.flutter.dev

# API Reference
open https://api.flutter.dev
```

---

## 🎨 Customisation Rapide

### Changer la Couleur Principale
```dart
// lib/theme/app_colors.dart
static const Color deepBlue = Color(0xFF1F4788);
// Changez en
static const Color deepBlue = Color(0xFFVOTRE_COULEUR);
```

### Changer la Police
```dart
// lib/main.dart
GoogleFonts.poppinsTextTheme()
// Changez en
GoogleFonts.robotoTextTheme()
```

---

## 🚀 Workflow Recommandé

### Développement
```bash
1. flutter run              # Lancer
2. Modifier le code
3. Taper 'r' (hot reload)
4. Tester
5. Répéter 2-4
```

### Avant un Commit
```bash
1. flutter analyze          # Vérifier erreurs
2. dart format lib/         # Formater
3. flutter test             # Tester (futur)
4. git commit              # Commiter
```

### Build de Production
```bash
1. flutter clean
2. flutter pub get
3. flutter build apk --release
4. Tester sur appareil réel
5. Publier
```

---

## 💡 Astuces

### Mode Debug Plus Rapide
```bash
flutter run --no-sound-null-safety  # Si problème de null safety
flutter run --release               # Test en mode release
```

### Voir les FPS en Temps Réel
```bash
# Pendant l'exécution, appuyez sur 'P'
```

### Recharger les Assets Sans Redémarrer
```bash
# Hot reload ('r') recharge automatiquement les assets
```

---

## 🆘 En Cas de Problème

### Problème de Build
```bash
flutter clean
flutter pub get
rm -rf ios/Pods ios/Podfile.lock  # Si iOS
cd android && ./gradlew clean && cd ..  # Si Android
flutter run
```

### Problème de Dépendances
```bash
rm pubspec.lock
flutter pub get
```

### Problème de Cache
```bash
flutter pub cache repair
```

### Tout Réinitialiser
```bash
flutter clean
rm -rf .dart_tool
rm -rf build
rm pubspec.lock
flutter pub get
```

---

## 📞 Aide

```bash
# Aide générale
flutter --help

# Aide sur une commande
flutter run --help
flutter build --help

# Doctor
flutter doctor
flutter doctor -v
```

---

## 🎉 Commandes Express

```bash
# Quick start
flutter run

# Clean start
flutter clean && flutter pub get && flutter run

# Analyze & format
flutter analyze && dart format lib/

# Build release
flutter build apk --release
```

---

**Gardez ce fichier à portée de main pendant le développement !** 🚀

Pour plus d'infos : https://docs.flutter.dev/reference/flutter-cli

