import 'package:flutter/foundation.dart';
import 'package:sola/core/models/translation.dart';
import 'package:sola/data/repositories/library_repository.dart';
import 'package:sola/domain/services/file_service.dart';

class LanguageSubtag {
  final String subtag;
  final String description;
  final String suppressScript;
  final String scope;

  const LanguageSubtag({
    required this.subtag,
    required this.description,
    this.suppressScript = '',
    this.scope = '',
  });

  factory LanguageSubtag.fromJson(Map<String, dynamic> json) {
    return LanguageSubtag(
      subtag: json['subtag'] as String,
      description: json['description'] as String,
      suppressScript: json['suppress_script'] as String? ?? '',
      scope: json['scope'] as String? ?? '',
    );
  }
}

class LanguageInfo {
  final String bcp47;
  final String description;
  final String nativeName;
  final int translationCount;

  const LanguageInfo({
    required this.bcp47,
    required this.description,
    required this.nativeName,
    required this.translationCount,
  });
}

class LanguageRepository {
  final FileService _fileService;
  final LibraryRepository _libraryRepository;

  List<LanguageSubtag>? _subtags;
  Map<String, LanguageSubtag>? _subtagLookup;
  List<LanguageInfo>? _languagesWithTranslations;
  Map<String, List<Translation>>? _translationsByLanguage;

  LanguageRepository({
    required FileService fileService,
    required LibraryRepository libraryRepository,
  })  : _fileService = fileService,
        _libraryRepository = libraryRepository;

  Future<void> _ensureLoaded() async {
    if (_subtags != null && _languagesWithTranslations != null) return;

    debugPrint('[LanguageRepo] Loading language subtags...');
    final data = await _fileService.deserializeAsset('assets/language_subtags.json');
    _subtags = (data as List)
        .map((e) => LanguageSubtag.fromJson(e as Map<String, dynamic>))
        .toList();
    _subtagLookup = {for (final s in _subtags!) s.subtag: s};
    debugPrint('[LanguageRepo] Loaded ${_subtags!.length} subtags');

    final translations = await _libraryRepository.getAvailableTranslations();
    _translationsByLanguage = {};
    for (final t in translations) {
      (_translationsByLanguage![t.bcp47] ??= []).add(t);
    }

    _languagesWithTranslations = _translationsByLanguage!.entries.map((entry) {
      final bcp47 = entry.key;
      final translations = entry.value;
      final subtag = _subtagLookup![bcp47];
      final description = subtag?.description ?? translations.first.language;
      // Use the native language name (lang field from first translation)
      final nativeName = translations.first.language;
      return LanguageInfo(
        bcp47: bcp47,
        description: description,
        nativeName: nativeName,
        translationCount: translations.length,
      );
    }).toList()
      ..sort((a, b) => b.translationCount.compareTo(a.translationCount));

    debugPrint('[LanguageRepo] Built ${_languagesWithTranslations!.length} language groups');
  }

  Future<List<LanguageSubtag>> getAllSubtags() async {
    await _ensureLoaded();
    return _subtags!;
  }

  Future<List<LanguageInfo>> getLanguagesWithTranslations() async {
    await _ensureLoaded();
    return _languagesWithTranslations!;
  }

  Future<List<LanguageInfo>> search(String query) async {
    await _ensureLoaded();
    if (query.isEmpty) return _languagesWithTranslations!;

    final q = query.toLowerCase();

    // Search across all subtags (for the full BCP 47 picker)
    // but prioritize languages that have translations
    final withTranslations = _languagesWithTranslations!.where((lang) {
      return lang.description.toLowerCase().contains(q) ||
          lang.nativeName.toLowerCase().contains(q) ||
          lang.bcp47.toLowerCase().contains(q);
    }).toList();

    if (withTranslations.isNotEmpty) return withTranslations;

    // Fall back to searching all subtags
    final allMatches = _subtags!.where((s) {
      return s.description.toLowerCase().contains(q) ||
          s.subtag.toLowerCase().contains(q);
    }).map((s) => LanguageInfo(
          bcp47: s.subtag,
          description: s.description,
          nativeName: s.description,
          translationCount: 0,
        )).toList();

    return allMatches;
  }

  Future<List<Translation>> getTranslationsForLanguage(String bcp47) async {
    await _ensureLoaded();
    return _translationsByLanguage?[bcp47] ?? [];
  }

  Future<LanguageInfo?> getLanguageInfo(String bcp47) async {
    await _ensureLoaded();
    return _languagesWithTranslations?.firstWhere(
      (l) => l.bcp47 == bcp47,
      orElse: () {
        final subtag = _subtagLookup?[bcp47];
        return LanguageInfo(
          bcp47: bcp47,
          description: subtag?.description ?? bcp47,
          nativeName: subtag?.description ?? bcp47,
          translationCount: 0,
        );
      },
    );
  }
}
