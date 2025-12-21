import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../providers/settings_providers.dart';

/// Sélecteur de récitateur pour l'audio du Quran
class ReciterSelector extends ConsumerWidget {
  const ReciterSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedReciter = ref.watch(selectedReciterPersistentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.goldAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person,
                  color: isDark ? AppColors.darkBackground : AppColors.deepBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.paddingMedium),
              Text(
                'Récitateur',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.paddingMedium),
          ...AudioService.popularReciters.map((reciter) {
            final isSelected = selectedReciter == reciter['id'];
            return InkWell(
              onTap: () async {
                await ref
                    .read(selectedReciterPersistentProvider.notifier)
                    .setReciter(reciter['id']!);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Récitateur: ${reciter['name']}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
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
                ),
                child: Row(
                  children: [
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: isDark
                            ? AppColors.darkBackground
                            : AppColors.deepBlue,
                        size: 20,
                      ),
                    if (isSelected) const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reciter['name']!,
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
                          const SizedBox(height: 2),
                          Text(
                            reciter['arabicName']!,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: isSelected
                                  ? (isDark
                                            ? AppColors.darkBackground
                                            : AppColors.deepBlue)
                                        .withOpacity(0.7)
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
