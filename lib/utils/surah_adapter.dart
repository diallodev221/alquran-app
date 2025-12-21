import '../models/surah.dart';
import '../models/quran_models.dart';

/// Adaptateur pour convertir entre les anciens et nouveaux modèles
class SurahAdapter {
  /// Convertit SurahModel (API) vers Surah (UI)
  static Surah fromApiModel(SurahModel model) {
    return Surah(
      number: model.number,
      name: model.englishName,
      arabicName: model.name,
      englishName: model.englishName,
      revelationType: model.revelationType,
      numberOfAyahs: model.numberOfAyahs,
      meaning: model.englishNameTranslation,
    );
  }

  /// Convertit une liste de SurahModel vers Surah
  static List<Surah> fromApiModelList(List<SurahModel> models) {
    return models.map((model) => fromApiModel(model)).toList();
  }
}
