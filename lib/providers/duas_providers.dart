import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/duas_api_service.dart';

/// Provider pour le service de du'as
final duasApiServiceProvider = Provider<DuasApiService>((ref) {
  return DuasApiService();
});

/// Provider pour la Dua du jour
final duaOfTheDayProvider = FutureProvider<DuaModel>((ref) async {
  final service = ref.watch(duasApiServiceProvider);
  return await service.getDuaOfTheDay(language: 'fr');
});
