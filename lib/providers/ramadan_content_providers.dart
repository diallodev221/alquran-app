import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ramadan_content_service.dart';

/// Provider pour le service de contenu Ramadan
final ramadanContentServiceProvider = Provider<RamadanContentService>((ref) {
  return RamadanContentService();
});

/// Provider pour le fait Ramadan du jour
final ramadanFactOfTheDayProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(ramadanContentServiceProvider);
  return await service.getRamadanFactOfTheDay();
});

/// Provider pour la citation de cheikh du jour
final scholarQuoteOfTheDayProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(ramadanContentServiceProvider);
  return await service.getScholarQuoteOfTheDay();
});
