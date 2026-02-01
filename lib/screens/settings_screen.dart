import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/audio_providers.dart';
import '../providers/settings_providers.dart';
import '../services/audio_service.dart';
import '../providers/prayer_times_providers.dart';
import '../utils/responsive_utils.dart';
import '../utils/available_translations.dart';

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
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  colors: [AppColors.darkBackground, AppColors.darkSurface],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : LinearGradient(
                  colors: [AppColors.ivory, AppColors.pureWhite],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: CustomScrollView(
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
                      padding: EdgeInsets.all(
                        ResponsiveUtils.adaptivePadding(
                          context,
                          mobile: AppTheme.paddingLarge,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(
                                  ResponsiveUtils.adaptivePadding(
                                    context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16,
                                  ),
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.luxuryGold.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.settings,
                                  color: AppColors.luxuryGold,
                                  size: ResponsiveUtils.adaptiveIconSize(
                                    context,
                                    base: 32,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: ResponsiveUtils.adaptivePadding(
                                  context,
                                  mobile: AppTheme.paddingMedium,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Paramètres',
                                      style: TextStyle(
                                        fontSize:
                                            ResponsiveUtils.adaptiveFontSize(
                                              context,
                                              mobile: 28,
                                              tablet: 32,
                                              desktop: 36,
                                            ),
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.pureWhite,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Personnalisez votre expérience',
                                      style: TextStyle(
                                        fontSize:
                                            ResponsiveUtils.adaptiveFontSize(
                                              context,
                                              mobile: 14,
                                              tablet: 15,
                                              desktop: 16,
                                            ),
                                        color: AppColors.pureWhite.withOpacity(
                                          0.8,
                                        ),
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
                padding: EdgeInsets.all(
                  ResponsiveUtils.adaptivePadding(
                    context,
                    mobile: AppTheme.paddingMedium,
                  ),
                ),
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
                        _buildThemeModeTile(isDark),
                        _buildDivider(),
                        _buildArabicFontSizeTile(isDark),
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
                        _buildPlaybackSpeedTile(isDark),
                      ],
                    ),

                    const SizedBox(height: AppTheme.paddingLarge),

                    // Section Traduction
                    _buildSectionTitle('Traduction', Icons.translate, isDark),
                    const SizedBox(height: AppTheme.paddingSmall),
                    _buildSettingsCard(
                      isDark: isDark,
                      children: [
                        _buildTranslationEditionTile(isDark),
                        _buildDivider(),
                        _buildShowTranslationTile(isDark),
                      ],
                    ),

                    const SizedBox(height: AppTheme.paddingLarge),

                    // Section Rappels & Notifications
                    _buildSectionTitle(
                      'Rappels & Notifications',
                      Icons.notifications_active,
                      isDark,
                    ),
                    const SizedBox(height: AppTheme.paddingSmall),
                    _buildSettingsCard(
                      isDark: isDark,
                      children: [
                        _buildAdhanSelectorTile(isDark),
                        _buildDivider(),
                        _buildSuhoorReminderTile(isDark),
                        _buildDivider(),
                        _buildIftarReminderTile(isDark),
                        _buildDivider(),
                        _buildSilentModeTile(isDark),
                        _buildDivider(),
                        _buildAdaptiveNotificationsTile(isDark),
                      ],
                    ),

                    const SizedBox(height: AppTheme.paddingLarge),

                    // Section Données
                    _buildSectionTitle(
                      'Données',
                      Icons.storage_outlined,
                      isDark,
                    ),
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

                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingXLarge,
                      ),
                    ),

                    // Footer
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'القرآن الكريم',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: ResponsiveUtils.adaptiveFontSize(
                                context,
                                mobile: 24,
                                tablet: 26,
                                desktop: 28,
                              ),
                              fontWeight: FontWeight.bold,
                              color: AppColors.luxuryGold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Made with ❤️ for the Muslim community',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.adaptiveFontSize(
                                context,
                                mobile: 12,
                                tablet: 13,
                                desktop: 14,
                              ),
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      height: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: AppTheme.paddingXLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingSmall,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: ResponsiveUtils.adaptiveIconSize(context, base: 20),
            color: AppColors.luxuryGold,
          ),
          SizedBox(width: ResponsiveUtils.adaptivePadding(context, mobile: 8)),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  context,
                  mobile: 16,
                  tablet: 17,
                  desktop: 18,
                ),
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.luxuryGold : AppColors.deepBlue,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

  Widget _buildThemeModeTile(bool isDark) {
    final themeMode = ref.watch(themeModeProvider);

    String getThemeModeName(ThemeMode mode) {
      switch (mode) {
        case ThemeMode.light:
          return 'Clair';
        case ThemeMode.dark:
          return 'Sombre';
        case ThemeMode.system:
          return 'Système';
      }
    }

    IconData getThemeModeIcon(ThemeMode mode) {
      switch (mode) {
        case ThemeMode.light:
          return Icons.light_mode;
        case ThemeMode.dark:
          return Icons.dark_mode;
        case ThemeMode.system:
          return Icons.brightness_auto;
      }
    }

    return _buildNavigationTile(
      title: 'Thème',
      subtitle: getThemeModeName(themeMode),
      icon: getThemeModeIcon(themeMode),
      onTap: () {
        HapticFeedback.lightImpact();
        _showThemeModeDialog(context, isDark);
      },
      isDark: isDark,
    );
  }

  Widget _buildArabicFontSizeTile(bool isDark) {
    final fontSize = ref.watch(arabicFontSizeProvider);

    return _buildSliderTile(
      title: 'Taille du texte arabe',
      subtitle: '${fontSize.toInt()} px',
      icon: Icons.format_size,
      value: fontSize,
      min: 20.0,
      max: 40.0,
      divisions: 20,
      onChanged: (value) async {
        HapticFeedback.lightImpact();
        await ref.read(arabicFontSizeProvider.notifier).updateSize(value);
      },
      isDark: isDark,
    );
  }

  Widget _buildPlaybackSpeedTile(bool isDark) {
    final speed = ref.watch(playbackSpeedProvider);

    return _buildSliderTile(
      title: 'Vitesse de lecture',
      subtitle: '${speed.toStringAsFixed(1)}x',
      icon: Icons.speed,
      value: speed,
      min: 0.5,
      max: 2.0,
      divisions: 15,
      onChanged: (value) async {
        HapticFeedback.lightImpact();
        await ref.read(playbackSpeedProvider.notifier).updateSpeed(value);

        // Mettre à jour la vitesse du lecteur audio si en cours
        try {
          final playlistService = ref.read(globalAudioPlaylistServiceProvider);
          await playlistService.setSpeed(value);
        } catch (e) {
          // Pas de lecture en cours, ignorer
        }
      },
      isDark: isDark,
    );
  }

  Widget _buildTranslationEditionTile(bool isDark) {
    final edition = ref.watch(translationEditionProvider);
    final editionName = AvailableTranslations.getName(edition);

    return _buildNavigationTile(
      title: 'Langue de traduction',
      subtitle: editionName,
      icon: Icons.language,
      onTap: () {
        HapticFeedback.lightImpact();
        _showTranslationDialog(context, isDark);
      },
      isDark: isDark,
    );
  }

  Widget _buildShowTranslationTile(bool isDark) {
    final showTranslation = ref.watch(showTranslationDefaultProvider);

    return _buildSwitchTile(
      title: 'Afficher par défaut',
      subtitle: 'Afficher la traduction automatiquement',
      icon: Icons.visibility,
      value: showTranslation,
      onChanged: (value) async {
        HapticFeedback.lightImpact();
        await ref.read(showTranslationDefaultProvider.notifier).toggle(value);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value
                    ? 'Traduction affichée par défaut'
                    : 'Traduction masquée par défaut',
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
        padding: EdgeInsets.all(
          ResponsiveUtils.adaptivePadding(context, mobile: 8),
        ),
        decoration: BoxDecoration(
          color: AppColors.luxuryGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: AppColors.luxuryGold,
          size: ResponsiveUtils.adaptiveIconSize(context, base: 20),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: ResponsiveUtils.adaptiveFontSize(
            context,
            mobile: 16,
            tablet: 17,
            desktop: 18,
          ),
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: ResponsiveUtils.adaptiveFontSize(
            context,
            mobile: 13,
            tablet: 14,
            desktop: 15,
          ),
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.luxuryGold,
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
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingMedium,
        ),
        vertical: ResponsiveUtils.adaptivePadding(
          context,
          mobile: AppTheme.paddingSmall,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  ResponsiveUtils.adaptivePadding(context, mobile: 8),
                ),
                decoration: BoxDecoration(
                  color: AppColors.luxuryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.luxuryGold,
                  size: ResponsiveUtils.adaptiveIconSize(context, base: 20),
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.adaptivePadding(context, mobile: 12),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 16,
                          tablet: 17,
                          desktop: 18,
                        ),
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 13,
                          tablet: 14,
                          desktop: 15,
                        ),
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        padding: EdgeInsets.all(
          ResponsiveUtils.adaptivePadding(context, mobile: 8),
        ),
        decoration: BoxDecoration(
          color: AppColors.luxuryGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: AppColors.luxuryGold,
          size: ResponsiveUtils.adaptiveIconSize(context, base: 20),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: ResponsiveUtils.adaptiveFontSize(
            context,
            mobile: 16,
            tablet: 17,
            desktop: 18,
          ),
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: ResponsiveUtils.adaptiveFontSize(
            context,
            mobile: 13,
            tablet: 14,
            desktop: 15,
          ),
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
        padding: EdgeInsets.all(
          ResponsiveUtils.adaptivePadding(context, mobile: 8),
        ),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.error.withOpacity(0.1)
              : AppColors.luxuryGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive ? AppColors.error : AppColors.luxuryGold,
          size: ResponsiveUtils.adaptiveIconSize(context, base: 20),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: ResponsiveUtils.adaptiveFontSize(
            context,
            mobile: 16,
            tablet: 17,
            desktop: 18,
          ),
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? AppColors.error
              : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: ResponsiveUtils.adaptiveFontSize(
            context,
            mobile: 13,
            tablet: 14,
            desktop: 15,
          ),
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: ResponsiveUtils.responsive(
        context,
        mobile: 56,
        tablet: 60,
        desktop: 64,
      ),
    );
  }

  Widget _buildReciterTile(bool isDark) {
    final selectedReciter = ref.watch(selectedReciterPersistentProvider);
    final list = AudioService.popularReciters
        .where((r) => r['id'] == selectedReciter)
        .toList();
    final reciterName =
        list.isNotEmpty ? (list.first['name'] ?? 'Mishary Rashid Alafasy') : 'Mishary Rashid Alafasy';

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
  void _showThemeModeDialog(BuildContext context, bool isDark) {
    final currentThemeMode = ref.read(themeModeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.pureWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(
          ResponsiveUtils.adaptivePadding(
            context,
            mobile: AppTheme.paddingLarge,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choisir le thème',
              style: TextStyle(
                fontSize: ResponsiveUtils.adaptiveFontSize(
                  context,
                  mobile: 20,
                  tablet: 22,
                  desktop: 24,
                ),
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            ...[
              {
                'mode': ThemeMode.system,
                'name': 'Système',
                'icon': Icons.brightness_auto,
              },
              {
                'mode': ThemeMode.light,
                'name': 'Clair',
                'icon': Icons.light_mode,
              },
              {
                'mode': ThemeMode.dark,
                'name': 'Sombre',
                'icon': Icons.dark_mode,
              },
            ].map((theme) {
              final mode = theme['mode'] as ThemeMode;
              final name = theme['name'] as String;
              final icon = theme['icon'] as IconData;
              final isSelected = currentThemeMode == mode;

              return ListTile(
                leading: Icon(
                  icon,
                  color: isSelected
                      ? AppColors.luxuryGold
                      : (isDark
                            ? AppColors.pureWhite.withOpacity(0.5)
                            : AppColors.textSecondary),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 16,
                      tablet: 17,
                      desktop: 18,
                    ),
                    color: isDark ? AppColors.pureWhite : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: AppColors.luxuryGold)
                    : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Thème "$name" sélectionné'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.luxuryGold,
                      ),
                    );
                  }
                },
              );
            }),
            const SizedBox(height: AppTheme.paddingMedium),
          ],
        ),
      ),
    );
  }

  void _showReciterDialog(BuildContext context, bool isDark) {
    final popularReciters = AudioService.popularReciters;
    final selectedReciter = ref.read(selectedReciterPersistentProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.pureWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(
                ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingLarge,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Choisir un récitateur',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 20,
                        tablet: 22,
                        desktop: 24,
                      ),
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark
                          ? AppColors.pureWhite.withOpacity(0.7)
                          : AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
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
                        final currentSurah = ref.read(
                          currentPlayingSurahProvider,
                        );
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
                            final audioUrls = await audioService
                                .getSurahAudioUrls(
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
          ],
        ),
      ),
    );
  }

  void _showTranslationDialog(BuildContext context, bool isDark) {
    final selectedEdition = ref.read(translationEditionProvider);

    // Créer une liste plate de toutes les traductions
    final allTranslations = <Map<String, String>>[];
    for (final category in AvailableTranslations.all.values) {
      allTranslations.addAll(category);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.pureWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(
                ResponsiveUtils.adaptivePadding(
                  context,
                  mobile: AppTheme.paddingLarge,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Langue de traduction',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.adaptiveFontSize(
                        context,
                        mobile: 20,
                        tablet: 22,
                        desktop: 24,
                      ),
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark
                          ? AppColors.pureWhite.withOpacity(0.7)
                          : AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allTranslations.length,
                itemBuilder: (context, index) {
                  final translation = allTranslations[index];
                  final identifier = translation['id'] as String;
                  final name = translation['name'] as String;
                  final isSelected = identifier == selectedEdition;

                  return RadioListTile<String>(
                    title: Text(
                      name,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: translation['language'] != null
                        ? Text(
                            translation['language']!,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    value: identifier,
                    groupValue: selectedEdition,
                    activeColor: AppColors.luxuryGold,
                    onChanged: (value) async {
                      if (value != null) {
                        HapticFeedback.lightImpact();
                        await ref
                            .read(translationEditionProvider.notifier)
                            .setTranslationEdition(value);
                        Navigator.pop(context);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Traduction: $name'),
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
          ],
        ),
      ),
    );
  }

  Widget _buildAdhanSelectorTile(bool isDark) {
    final selectedAdhan = ref.watch(selectedAdhanProvider);

    String getAdhanDisplayName(String adhanName) {
      switch (adhanName) {
        case 'classic':
          return 'Classique';
        case 'makkah':
          return 'Makkah';
        case 'madinah':
          return 'Madinah';
        case 'egyptian':
          return 'Égyptien';
        case 'turkish':
          return 'Turc';
        default:
          return 'Classique';
      }
    }

    return _buildNavigationTile(
      title: 'Adhan audio',
      subtitle: 'Voix: ${getAdhanDisplayName(selectedAdhan)}',
      icon: Icons.music_note,
      onTap: () {
        HapticFeedback.lightImpact();
        _showAdhanSelectorDialog(context, isDark);
      },
      isDark: isDark,
    );
  }

  Widget _buildSuhoorReminderTile(bool isDark) {
    final isEnabled = ref.watch(suhoorReminderProvider);
    final minutes = ref.watch(suhoorReminderMinutesProvider);

    return Column(
      children: [
        _buildSwitchTile(
          title: 'Rappel suhoor intelligent',
          subtitle: isEnabled
              ? '$minutes minutes avant imsak'
              : 'Rappel avant le suhoor',
          icon: Icons.alarm_add,
          value: isEnabled,
          onChanged: (value) async {
            HapticFeedback.lightImpact();
            await ref.read(suhoorReminderProvider.notifier).toggle(value);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    value ? 'Rappel suhoor activé' : 'Rappel suhoor désactivé',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.luxuryGold,
                ),
              );
            }
          },
          isDark: isDark,
        ),
        if (isEnabled) ...[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.adaptivePadding(
                context,
                mobile: AppTheme.paddingMedium,
              ),
              vertical: ResponsiveUtils.adaptivePadding(
                context,
                mobile: AppTheme.paddingSmall,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: AppColors.luxuryGold,
                      size: ResponsiveUtils.adaptiveIconSize(context, base: 18),
                    ),
                    SizedBox(
                      width: ResponsiveUtils.adaptivePadding(
                        context,
                        mobile: 8,
                      ),
                    ),
                    Text(
                      'Minutes avant imsak',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.adaptiveFontSize(
                          context,
                          mobile: 14,
                          tablet: 15,
                          desktop: 16,
                        ),
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: minutes.toDouble(),
                  min: 10,
                  max: 120,
                  divisions: 22, // 10, 15, 20, ..., 120 (par pas de 5)
                  label: '$minutes min',
                  activeColor: AppColors.luxuryGold,
                  inactiveColor: AppColors.luxuryGold.withOpacity(0.2),
                  onChanged: (value) async {
                    HapticFeedback.lightImpact();
                    final roundedMinutes = ((value / 5).round() * 5).toInt();
                    await ref
                        .read(suhoorReminderMinutesProvider.notifier)
                        .setMinutes(roundedMinutes);
                  },
                ),
                Text(
                  '$minutes minutes avant imsak',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14,
                    ),
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIftarReminderTile(bool isDark) {
    final isEnabled = ref.watch(iftarReminderProvider);

    return _buildSwitchTile(
      title: 'Rappel iftar avec invocation',
      subtitle: 'Notification avec doua à l\'iftar',
      icon: Icons.wb_sunny,
      value: isEnabled,
      onChanged: (value) async {
        HapticFeedback.lightImpact();
        await ref.read(iftarReminderProvider.notifier).toggle(value);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value ? 'Rappel iftar activé' : 'Rappel iftar désactivé',
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

  Widget _buildSilentModeTile(bool isDark) {
    final isEnabled = ref.watch(silentModeDuringPrayerProvider);

    return _buildSwitchTile(
      title: 'Mode silencieux auto',
      subtitle: 'Activer automatiquement pendant la prière',
      icon: Icons.volume_off,
      value: isEnabled,
      onChanged: (value) async {
        HapticFeedback.lightImpact();
        await ref.read(silentModeDuringPrayerProvider.notifier).toggle(value);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value
                    ? 'Mode silencieux activé pendant la prière'
                    : 'Mode silencieux désactivé',
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

  Widget _buildAdaptiveNotificationsTile(bool isDark) {
    final isEnabled = ref.watch(adaptiveNotificationsProvider);

    return _buildSwitchTile(
      title: 'Notifications adaptatives',
      subtitle: 'Réduction automatique la nuit',
      icon: Icons.brightness_2,
      value: isEnabled,
      onChanged: (value) async {
        HapticFeedback.lightImpact();
        await ref.read(adaptiveNotificationsProvider.notifier).toggle(value);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value
                    ? 'Notifications adaptatives activées'
                    : 'Notifications adaptatives désactivées',
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

  void _showAdhanSelectorDialog(BuildContext context, bool isDark) {
    final selectedAdhan = ref.read(selectedAdhanProvider);

    String getAdhanDisplayName(String adhanName) {
      switch (adhanName) {
        case 'classic':
          return 'Classique';
        case 'makkah':
          return 'Makkah';
        case 'madinah':
          return 'Madinah';
        case 'egyptian':
          return 'Égyptien';
        case 'turkish':
          return 'Turc';
        default:
          return 'Classique';
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.pureWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(
          ResponsiveUtils.adaptivePadding(
            context,
            mobile: AppTheme.paddingLarge,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Choisir la voix d\'Adhan',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 20,
                      tablet: 22,
                      desktop: 24,
                    ),
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark
                        ? AppColors.pureWhite.withOpacity(0.7)
                        : AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            ...['classic', 'makkah', 'madinah', 'egyptian', 'turkish'].map((
              adhan,
            ) {
              final isSelected = selectedAdhan == adhan;
              return ListTile(
                leading: Icon(
                  Icons.music_note,
                  color: isSelected
                      ? AppColors.luxuryGold
                      : (isDark
                            ? AppColors.pureWhite.withOpacity(0.5)
                            : AppColors.textSecondary),
                ),
                title: Text(
                  getAdhanDisplayName(adhan),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.adaptiveFontSize(
                      context,
                      mobile: 16,
                      tablet: 17,
                      desktop: 18,
                    ),
                    color: isDark ? AppColors.pureWhite : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: AppColors.luxuryGold)
                    : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(selectedAdhanProvider.notifier).setAdhan(adhan);
                  Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Adhan: ${getAdhanDisplayName(adhan)}'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.luxuryGold,
                      ),
                    );
                  }
                },
              );
            }),
            const SizedBox(height: AppTheme.paddingMedium),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Vider le cache',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
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
            child: Text(
              'Annuler',
              style: TextStyle(
                color: isDark
                    ? AppColors.pureWhite.withOpacity(0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Cache vidé avec succès'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.luxuryGold,
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
