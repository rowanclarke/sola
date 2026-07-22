import 'package:flutter/foundation.dart';
import 'package:sola/core/models/language_tag.dart';
import 'package:sola/core/models/translation.dart';
import 'package:sola/data/repositories/library_repository.dart';
import 'package:sola/domain/services/file_service.dart';

class LanguageData {
  final String autonym;
  final String englishName;
  final String defaultScript;

  const LanguageData({
    required this.autonym,
    required this.englishName,
    required this.defaultScript,
  });

  factory LanguageData.fromJson(Map<String, dynamic> json) {
    return LanguageData(
      autonym: json['autonym'] as String,
      englishName: json['english_name'] as String,
      defaultScript: json['default_script'] as String? ?? '',
    );
  }
}

class LanguageInfo {
  final String languageCode;
  final String baseLanguageCode;
  final String description;
  final String nativeName;
  final String? dialectName;
  final int translationCount;

  const LanguageInfo({
    required this.languageCode,
    required this.baseLanguageCode,
    required this.description,
    required this.nativeName,
    this.dialectName,
    required this.translationCount,
  });
}

class LanguageRepository {
  final FileService _fileService;
  final LibraryRepository _libraryRepository;

  Map<String, LanguageData>? _languageDataLookup;
  List<LanguageInfo>? _languagesWithTranslations;
  List<Translation>? _allTranslations;

  LanguageRepository({
    required FileService fileService,
    required LibraryRepository libraryRepository,
  })  : _fileService = fileService,
        _libraryRepository = libraryRepository;

  Future<void> _ensureLoaded() async {
    if (_languageDataLookup != null && _languagesWithTranslations != null) return;

    debugPrint('[LanguageRepo] Loading language data...');
    final data = await _fileService.deserializeAsset('assets/language_data.json');
    final map = data as Map<String, dynamic>;
    _languageDataLookup = map.map(
      (key, value) => MapEntry(key, LanguageData.fromJson(value as Map<String, dynamic>)),
    );
    debugPrint('[LanguageRepo] Loaded ${_languageDataLookup!.length} language entries');

    _allTranslations = await _libraryRepository.getAvailableTranslations();

    final translationsByGroup = <String, List<Translation>>{};
    for (final t in _allTranslations!) {
      final tag = t.languageTag;
      final key = tag.region != null ? '${tag.language}-${tag.region}' : tag.language;
      (translationsByGroup[key] ??= []).add(t);
    }

    _languagesWithTranslations = translationsByGroup.entries.map((entry) {
      final groupCode = entry.key;
      final translations = entry.value;
      final baseLang = translations.first.languageTag.language;
      final langData = _languageDataLookup![baseLang];
      final description = langData?.englishName ?? translations.first.langEn;
      final nativeName = langData?.autonym ?? translations.first.lang;

      final firstTag = translations.first.languageTag;
      final dialectName = firstTag.displayName(description);

      return LanguageInfo(
        languageCode: groupCode,
        baseLanguageCode: baseLang,
        description: description,
        nativeName: nativeName,
        dialectName: dialectName != description ? dialectName : null,
        translationCount: translations.length,
      );
    }).toList()
      ..sort((a, b) => b.translationCount.compareTo(a.translationCount));

    debugPrint('[LanguageRepo] Built ${_languagesWithTranslations!.length} language groups');
  }

  Future<List<LanguageInfo>> getLanguagesWithTranslations() async {
    await _ensureLoaded();
    return _languagesWithTranslations!;
  }

  Future<List<LanguageInfo>> search(String query) async {
    await _ensureLoaded();
    if (query.isEmpty) return _languagesWithTranslations!;

    final q = query.toLowerCase();

    final results = _languagesWithTranslations!.where((lang) {
      return lang.description.toLowerCase().contains(q) ||
          lang.nativeName.toLowerCase().contains(q) ||
          lang.languageCode.toLowerCase().contains(q) ||
          (lang.dialectName?.toLowerCase().contains(q) ?? false);
    }).toList();

    return results;
  }

  Future<List<Translation>> findTranslations(LanguageTag tag) async {
    await _ensureLoaded();
    return _allTranslations!.where((t) => tag.matches(t.languageTag)).toList();
  }

  Future<LanguageInfo?> getLanguageInfo(String languageCode) async {
    await _ensureLoaded();
    return _languagesWithTranslations?.firstWhere(
      (l) => l.languageCode == languageCode,
      orElse: () {
        final baseLang = LanguageTag.parse(languageCode).language;
        final langData = _languageDataLookup?[baseLang];
        return LanguageInfo(
          languageCode: languageCode,
          baseLanguageCode: baseLang,
          description: langData?.englishName ?? languageCode,
          nativeName: langData?.autonym ?? languageCode,
          translationCount: 0,
        );
      },
    );
  }
}
