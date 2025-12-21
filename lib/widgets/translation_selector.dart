import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/available_translations.dart';
import '../providers/quran_providers.dart';

/// Sélecteur de traduction pour le Quran
class TranslationSelector extends ConsumerWidget {
  final bool showInSheet;

  const TranslationSelector({super.key, this.showInSheet = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedEdition = ref.watch(selectedEditionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: showInSheet
          ? null
          : BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.pureWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: AppColors.cardShadow,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!showInSheet)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.translate,
                    color: isDark
                        ? AppColors.darkBackground
                        : AppColors.deepBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.paddingMedium),
                Text(
                  'Traduction',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          if (!showInSheet) const SizedBox(height: AppTheme.paddingMedium),

          // Liste des traductions par catégorie
          ...AvailableTranslations.all.entries.map((entry) {
            final category = entry.key;
            final translations = entry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.paddingSmall,
                  ),
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.luxuryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...translations.map((translation) {
                  final isSelected = selectedEdition == translation['id'];
                  return _buildTranslationTile(
                    context,
                    ref,
                    translation,
                    isSelected,
                    isDark,
                  );
                }),
                const SizedBox(height: AppTheme.paddingSmall),
              ],
            );
          }),
        ],
      ),
    );

    if (showInSheet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Row(
              children: [
                const Icon(Icons.translate, color: AppColors.luxuryGold),
                const SizedBox(width: 8),
                Text(
                  'Choisir une Traduction',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          Expanded(child: SingleChildScrollView(child: content)),
        ],
      );
    }

    return content;
  }

  Widget _buildTranslationTile(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> translation,
    bool isSelected,
    bool isDark,
  ) {
    return InkWell(
      onTap: () {
        ref.read(selectedEditionProvider.notifier).state = translation['id']!;

        // Invalider les caches pour recharger avec nouvelle traduction
        ref.invalidate(surahDetailProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Traduction: ${translation['name']}'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.success,
          ),
        );
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingMedium,
          vertical: AppTheme.paddingSmall,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.goldAccent : null,
          color: isSelected
              ? null
              : (isDark
                    ? AppColors.darkBackground.withOpacity(0.3)
                    : AppColors.ivory.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: isSelected
              ? Border.all(color: AppColors.luxuryGold, width: 2)
              : null,
        ),
        child: Row(
          children: [
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: isDark ? AppColors.darkBackground : AppColors.deepBlue,
                size: 20,
              ),
            if (isSelected) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translation['name']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? (isDark
                                ? AppColors.darkBackground
                                : AppColors.deepBlue)
                          : null,
                    ),
                  ),
                  if (translation['description'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      translation['description']!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? (isDark
                                      ? AppColors.darkBackground
                                      : AppColors.deepBlue)
                                  .withOpacity(0.7)
                            : Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (isDark ? AppColors.darkBackground : AppColors.deepBlue)
                          .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Actif',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkBackground
                        : AppColors.deepBlue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
