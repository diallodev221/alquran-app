import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/personalization_service.dart';
import '../services/user_behavior_service.dart';

/// Provider pour le service de comportement utilisateur
final userBehaviorServiceProvider = Provider<UserBehaviorService>((ref) {
  return UserBehaviorService();
});

/// Provider pour le service de personnalisation
final personalizationServiceProvider = Provider<PersonalizationService>((ref) {
  return PersonalizationService();
});

/// Provider pour la configuration de personnalisation
final personalizationConfigProvider =
    FutureProvider<PersonalizationConfig>((ref) async {
  final service = ref.watch(personalizationServiceProvider);
  // Analyser et mettre à jour automatiquement
  return await service.analyzeAndUpdate();
});

/// Provider pour obtenir le type d'audio préféré
final preferredAudioTypeProvider = FutureProvider<String?>((ref) async {
  final behaviorService = ref.watch(userBehaviorServiceProvider);
  return await behaviorService.getMostPlayedAudioType(days: 7);
});

/// Provider pour obtenir le moment préféré pour le Quran
final preferredQuranTimeProvider = FutureProvider<String?>((ref) async {
  final behaviorService = ref.watch(userBehaviorServiceProvider);
  return await behaviorService.getPreferredQuranTime(days: 14);
});

/// Provider pour vérifier si une suggestion contextuelle doit être affichée
final shouldShowQuranSuggestionProvider =
    FutureProvider.family<bool, DateTime>((ref, now) async {
  final service = ref.watch(personalizationServiceProvider);
  return await service.shouldShowContextualSuggestion('quran', now);
});
