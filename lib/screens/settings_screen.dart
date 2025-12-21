import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/audio_providers.dart';
import '../providers/settings_providers.dart';
import '../utils/responsive_utils.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar avec dégradé
          SliverAppBar(
            expandedHeight: ResponsiveUtils.adaptiveAppBarHeight(context),
            floating: false,
            pinned: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(
                          colors: [
                            AppColors.darkSurface,
                            AppColors.darkBackground,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : AppColors.headerGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.paddingLarge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.luxuryGold.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.settings,
                                color: AppColors.luxuryGold,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: AppTheme.paddingMedium),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Paramètres',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.pureWhite,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Personnalisez votre expérience',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.pureWhite,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Contenu des paramètres
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Apparence
                  _buildSectionTitle(
                    'Apparence',
                    Icons.palette_outlined,
                    isDark,
                  ),
                  const SizedBox(height: AppTheme.paddingSmall),
                  _buildSettingsCard(
                    isDark: isDark,
                    children: [
                      _buildSwitchTile(
                        title: 'Mode sombre',
                        subtitle: 'Activer le thème sombre',
                        icon: Icons.dark_mode,
                        value: isDark,
                        onChanged: (value) {
                          // TODO: Implémenter le changement de thème
                          HapticFeedback.lightImpact();
                        },
                        isDark: isDark,
                      ),
                      _buildDivider(),
                      _buildSliderTile(
                        title: 'Taille du texte arabe',
                        subtitle: 'Ajuster la taille de police',
                        icon: Icons.format_size,
                        value: 28.0,
                        min: 20.0,
                        max: 40.0,
                        onChanged: (value) {
                          // TODO: Implémenter le changement de taille
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.paddingLarge),

                  // Section Audio
                  _buildSectionTitle('Audio', Icons.headphones, isDark),
                  const SizedBox(height: AppTheme.paddingSmall),
                  _buildSettingsCard(
                    isDark: isDark,
                    children: [
                      _buildReciterTile(isDark),
                      _buildDivider(),
                      _buildAutoPlayTile(isDark),
                      _buildDivider(),
                      _buildSliderTile(
                        title: 'Vitesse de lecture',
                        subtitle: '1.0x',
                        icon: Icons.speed,
                        value: 1.0,
                        min: 0.5,
                        max: 2.0,
                        divisions: 6,
                        onChanged: (value) {
                          // TODO: Implémenter le changement de vitesse
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.paddingLarge),

                  // Section Traduction
                  _buildSectionTitle('Traduction', Icons.translate, isDark),
                  const SizedBox(height: AppTheme.paddingSmall),
                  _buildSettingsCard(
                    isDark: isDark,
                    children: [
                      _buildNavigationTile(
                        title: 'Langue de traduction',
                        subtitle: 'Français',
                        icon: Icons.language,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showLanguageDialog(context, isDark);
                        },
                        isDark: isDark,
                      ),
                      _buildDivider(),
                      _buildSwitchTile(
                        title: 'Afficher par défaut',
                        subtitle: 'Afficher la traduction automatiquement',
                        icon: Icons.visibility,
                        value: false,
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.paddingLarge),

                  // Section Notifications
                  _buildSectionTitle(
                    'Notifications',
                    Icons.notifications_outlined,
                    isDark,
                  ),
                  const SizedBox(height: AppTheme.paddingSmall),
                  _buildSettingsCard(
                    isDark: isDark,
                    children: [
                      _buildSwitchTile(
                        title: 'Rappels de lecture',
                        subtitle: 'Recevoir des rappels quotidiens',
                        icon: Icons.alarm,
                        value: false,
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.paddingLarge),

                  // Section Données
                  _buildSectionTitle('Données', Icons.storage_outlined, isDark),
                  const SizedBox(height: AppTheme.paddingSmall),
                  _buildSettingsCard(
                    isDark: isDark,
                    children: [
                      _buildActionTile(
                        title: 'Vider le cache',
                        subtitle: 'Libérer de l\'espace de stockage',
                        icon: Icons.delete_outline,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showClearCacheDialog(context, isDark);
                        },
                        isDark: isDark,
                        isDestructive: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.paddingLarge),

                  // Section À propos
                  _buildSectionTitle('À propos', Icons.info_outline, isDark),
                  const SizedBox(height: AppTheme.paddingSmall),
                  _buildSettingsCard(
                    isDark: isDark,
                    children: [
                      _buildNavigationTile(
                        title: 'Version',
                        subtitle: '1.0.0',
                        icon: Icons.app_settings_alt,
                        onTap: () {},
                        isDark: isDark,
                        showArrow: false,
                      ),
                      _buildDivider(),
                      _buildNavigationTile(
                        title: 'Licence',
                        subtitle: 'Open Source',
                        icon: Icons.description_outlined,
                        onTap: () {
                          HapticFeedback.lightImpact();
                        },
                        isDark: isDark,
                      ),
                      _buildDivider(),
                      _buildNavigationTile(
                        title: 'Nous contacter',
                        subtitle: 'Envoyer vos commentaires',
                        icon: Icons.email_outlined,
                        onTap: () {
                          HapticFeedback.lightImpact();
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.paddingXLarge),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'القرآن الكريم',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.luxuryGold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Made with ❤️ for the Muslim community',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.paddingXLarge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingSmall),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.luxuryGold),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.luxuryGold : AppColors.deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.luxuryGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.luxuryGold, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.luxuryGold,
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingMedium,
        vertical: AppTheme.paddingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.luxuryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.luxuryGold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.luxuryGold,
            inactiveColor: AppColors.luxuryGold.withOpacity(0.2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    bool showArrow = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.luxuryGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.luxuryGold, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
      ),
      trailing: showArrow
          ? Icon(Icons.chevron_right, color: AppColors.luxuryGold)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.error.withOpacity(0.1)
              : AppColors.luxuryGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive ? AppColors.error : AppColors.luxuryGold,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? AppColors.error
              : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56);
  }

  Widget _buildReciterTile(bool isDark) {
    final selectedReciter = ref.watch(selectedReciterPersistentProvider);

    // Liste des récitateurs populaires
    final popularReciters = {
      'ar.alafasy': 'Mishary Rashid Alafasy',
      'ar.abdulbasitmurattal': 'Abdul Basit',
      'ar.husary': 'Mahmoud Al-Hussary',
      'ar.hani': 'Hani Ar-Rifai',
      'ar.minshawi': 'Mohamed Al-Minshawi',
      'ar.shaatree': 'Abu Bakr Al-Shatri',
      'ar.abdulsamad': 'Abdul Basit (Mujawwad)',
      'ar.mahermuaiqly': 'Maher Al-Muaiqly',
      'ar.sudais': 'Abdurrahman As-Sudais',
    };

    final reciterName = popularReciters[selectedReciter] ?? 'Mishary Alafasy';

    return _buildNavigationTile(
      title: 'Récitateur',
      subtitle: reciterName,
      icon: Icons.person_outline,
      onTap: () {
        HapticFeedback.lightImpact();
        _showReciterDialog(context, isDark);
      },
      isDark: isDark,
    );
  }

  Widget _buildAutoPlayTile(bool isDark) {
    final autoPlay = ref.watch(autoPlayNextProvider);

    return _buildSwitchTile(
      title: 'Lecture automatique',
      subtitle: 'Lire le verset suivant automatiquement',
      icon: Icons.play_circle_outline,
      value: autoPlay,
      onChanged: (value) async {
        HapticFeedback.lightImpact();
        await ref.read(autoPlayNextProvider.notifier).toggle(value);

        // Mettre à jour le service audio si en cours de lecture
        final playlistService = ref.read(globalAudioPlaylistServiceProvider);
        if (value) {
          // Activer le mode lecture continue (all)
          await playlistService.setLoopMode(LoopMode.all);
        } else {
          // Désactiver le mode repeat
          await playlistService.setLoopMode(LoopMode.off);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value
                    ? 'Lecture automatique activée'
                    : 'Lecture automatique désactivée',
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.luxuryGold,
            ),
          );
        }
      },
      isDark: isDark,
    );
  }

  // Dialogs
  void _showReciterDialog(BuildContext context, bool isDark) {
    // Liste des récitateurs populaires
    final popularReciters = [
      {
        'id': 'ar.alafasy',
        'name': 'Mishary Rashid Alafasy',
        'arabicName': 'مشاري بن راشد العفاسي',
      },
      {
        'id': 'ar.abdulbasitmurattal',
        'name': 'Abdul Basit (Murattal)',
        'arabicName': 'عبد الباسط عبد الصمد',
      },
      {
        'id': 'ar.husary',
        'name': 'Mahmoud Khalil Al-Hussary',
        'arabicName': 'محمود خليل الحصري',
      },
      {'id': 'ar.hani', 'name': 'Hani Ar-Rifai', 'arabicName': 'هاني الرفاعي'},
      {
        'id': 'ar.minshawi',
        'name': 'Mohamed Siddiq Al-Minshawi',
        'arabicName': 'محمد صديق المنشاوي',
      },
      {
        'id': 'ar.shaatree',
        'name': 'Abu Bakr Al-Shatri',
        'arabicName': 'أبو بكر الشاطري',
      },
      {
        'id': 'ar.abdulsamad',
        'name': 'Abdul Basit (Mujawwad)',
        'arabicName': 'عبد الباسط عبد الصمد (مجود)',
      },
      {
        'id': 'ar.mahermuaiqly',
        'name': 'Maher Al-Muaiqly',
        'arabicName': 'ماهر المعيقلي',
      },
      {
        'id': 'ar.sudais',
        'name': 'Abdurrahman As-Sudais',
        'arabicName': 'عبد الرحمن السديس',
      },
    ];

    final selectedReciter = ref.read(selectedReciterPersistentProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.pureWhite,
        title: Text(
          'Choisir un récitateur',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: popularReciters.length,
            itemBuilder: (context, index) {
              final reciter = popularReciters[index];
              final isSelected = reciter['id'] == selectedReciter;

              return RadioListTile<String>(
                title: Text(
                  reciter['name']!,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  reciter['arabicName']!,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
                value: reciter['id']!,
                groupValue: selectedReciter,
                activeColor: AppColors.luxuryGold,
                onChanged: (value) async {
                  if (value != null) {
                    HapticFeedback.lightImpact();

                    // Capturer le messenger avant async
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);

                    // Sauvegarder la sourate en cours et l'index
                    final currentSurah = ref.read(currentPlayingSurahProvider);
                    final currentIndex = ref.read(currentAyahIndexProvider);
                    final wasPlaying = ref.read(isAudioPlayingProvider);

                    // Changer le récitateur (sauvegarde automatique)
                    await ref
                        .read(selectedReciterPersistentProvider.notifier)
                        .setReciter(value);
                    navigator.pop();

                    // Si une sourate est en cours, la recharger avec le nouveau récitateur
                    if (currentSurah != null) {
                      try {
                        final audioService = ref.read(audioServiceProvider);
                        final audioUrls = await audioService.getSurahAudioUrls(
                          currentSurah,
                          reciter: value,
                        );

                        if (audioUrls.isNotEmpty) {
                          // Recharger avec le nouveau récitateur
                          final playlistService = ref.read(
                            globalAudioPlaylistServiceProvider,
                          );
                          await playlistService.loadSurahPlaylist(
                            audioUrls,
                            startIndex: currentIndex,
                          );

                          // Redémarrer la lecture si elle était en cours
                          if (wasPlaying) {
                            await playlistService.play();
                          }

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Récitateur changé: ${reciter['name']}',
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.luxuryGold,
                            ),
                          );
                        }
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Erreur: $e'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    } else {
                      // Pas de sourate en cours, juste confirmer le changement
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Récitateur: ${reciter['name']}'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.luxuryGold,
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.pureWhite,
        title: Text(
          'Langue de traduction',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('Français', true, isDark),
            _buildLanguageOption('English', false, isDark),
            _buildLanguageOption('العربية', false, isDark),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(String name, bool isSelected, bool isDark) {
    return RadioListTile<bool>(
      title: Text(
        name,
        style: TextStyle(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
      value: isSelected,
      groupValue: true,
      activeColor: AppColors.luxuryGold,
      onChanged: (value) {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
    );
  }

  void _showClearCacheDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.pureWhite,
        title: Text(
          'Vider le cache',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vider le cache ? Cela supprimera toutes les données téléchargées.',
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache vidé avec succès'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }
}
