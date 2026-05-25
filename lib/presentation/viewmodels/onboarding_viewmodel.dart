import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sola/core/models/translation.dart';
import 'package:sola/data/repositories/language_repository.dart';
import 'package:sola/data/repositories/library_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

enum DownloadState { idle, downloading, ready }

class OnboardingViewModel extends ChangeNotifier {
  final LanguageRepository _languageRepository;
  final LibraryRepository _libraryRepository;
  final SessionRepository _sessionRepository;

  int _currentStep = 1;
  String? _selectedLanguageCode;
  LanguageInfo? _selectedLanguageInfo;
  String _detectedLanguageCode = '';
  LanguageInfo? _detectedLanguageInfo;

  String _languageQuery = '';
  List<LanguageInfo> _filteredLanguages = [];
  List<LanguageInfo> _allLanguages = [];

  List<Translation> _filteredTranslations = [];
  List<Translation> _allTranslationsForLanguage = [];
  String _translationQuery = '';
  Translation? _selectedTranslation;
  final Map<String, DownloadState> _downloadStates = {};
  final Map<String, double> _downloadProgress = {};
  CancelToken? _cancelToken;
  String? _downloadingId;

  bool _isLoading = false;

  OnboardingViewModel({
    required LanguageRepository languageRepository,
    required LibraryRepository libraryRepository,
    required SessionRepository sessionRepository,
  }) : _languageRepository = languageRepository,
       _libraryRepository = libraryRepository,
       _sessionRepository = sessionRepository;

  int get currentStep => _currentStep;
  String? get selectedLanguageCode => _selectedLanguageCode;
  LanguageInfo? get selectedLanguageInfo => _selectedLanguageInfo;
  String get detectedLanguageCode => _detectedLanguageCode;
  LanguageInfo? get detectedLanguageInfo => _detectedLanguageInfo;
  String get languageQuery => _languageQuery;
  List<LanguageInfo> get filteredLanguages => _filteredLanguages;
  List<Translation> get filteredTranslations => _filteredTranslations;
  String get translationQuery => _translationQuery;
  Translation? get selectedTranslation => _selectedTranslation;
  bool get isLoading => _isLoading;

  DownloadState getDownloadState(String translationId) {
    return _downloadStates[translationId] ?? DownloadState.idle;
  }

  double getDownloadProgress(String translationId) {
    return _downloadProgress[translationId] ?? 0.0;
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    // Detect device language
    final locale = PlatformDispatcher.instance.locale;
    _detectedLanguageCode = locale.languageCode;
    debugPrint(
      '[OnboardingVM] Detected device language: $_detectedLanguageCode',
    );

    // Load all languages
    _allLanguages = await _languageRepository.getLanguagesWithTranslations();
    _filteredLanguages = _allLanguages;

    // Find info for detected language
    _detectedLanguageInfo = await _languageRepository.getLanguageInfo(
      _detectedLanguageCode,
    );

    // Check for downloaded translations to pre-set download states
    final downloaded = await _libraryRepository.getDownloadedTranslations();
    for (final t in downloaded) {
      _downloadStates[t.id] = DownloadState.ready;
    }

    // Restore from persisted session if available
    final session = _sessionRepository.currentSession;
    if (session.currentLanguageCode != null) {
      _selectedLanguageCode = session.currentLanguageCode;
      _selectedLanguageInfo = await _languageRepository.getLanguageInfo(
        session.currentLanguageCode!,
      );
    } else if (_detectedLanguageInfo != null &&
        _detectedLanguageInfo!.translationCount > 0) {
      // Auto-select detected language if it has translations
      _selectedLanguageCode = _detectedLanguageCode;
      _selectedLanguageInfo = _detectedLanguageInfo;
    }

    // Restore selected translation from session
    if (session.currentTranslationId != null && _selectedLanguageCode != null) {
      final translations = await _languageRepository.getTranslationsForLanguage(
        _selectedLanguageCode!,
      );
      _selectedTranslation = translations
          .where((t) => t.id == session.currentTranslationId)
          .firstOrNull;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectLanguage(String bcp47) async {
    _selectedLanguageCode = bcp47;
    _selectedLanguageInfo = await _languageRepository.getLanguageInfo(bcp47);
    notifyListeners();
  }

  Future<void> goToTranslationStep() async {
    if (_selectedLanguageCode == null) return;

    _currentStep = 2;
    _translationQuery = '';
    _allTranslationsForLanguage = await _languageRepository
        .getTranslationsForLanguage(_selectedLanguageCode!);
    _filteredTranslations = _allTranslationsForLanguage;
    _selectedTranslation = null;

    // Persist language selection
    await _sessionRepository.setCurrentLanguage(_selectedLanguageCode!);

    notifyListeners();
  }

  Future<void> goToCompleteStep() async {
    if (_selectedTranslation == null) return;
    _currentStep = 3;

    // Persist translation selection
    await _sessionRepository.setCurrentTranslation(_selectedTranslation!.id);

    notifyListeners();
  }

  void goBackToLanguageStep() {
    _currentStep = 1;
    _selectedTranslation = null;
    _translationQuery = '';
    notifyListeners();
  }

  void goBackToTranslationStep() {
    _currentStep = 2;
    notifyListeners();
  }

  Future<void> searchLanguages(String query) async {
    _languageQuery = query;
    _filteredLanguages = await _languageRepository.search(query);
    notifyListeners();
  }

  void searchTranslations(String query) {
    _translationQuery = query;
    if (query.isEmpty) {
      _filteredTranslations = _allTranslationsForLanguage;
    } else {
      final q = query.toLowerCase();
      _filteredTranslations = _allTranslationsForLanguage.where((t) {
        return t.title.toLowerCase().contains(q) ||
            t.id.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q);
      }).toList();
    }
    notifyListeners();
  }

  Future<void> selectTranslation(Translation translation) async {
    if (getDownloadState(translation.id) != DownloadState.ready) return;
    _selectedTranslation = translation;
    notifyListeners();
  }

  Future<void> downloadTranslation(Translation translation) async {
    if (_downloadStates[translation.id] == DownloadState.ready) {
      await selectTranslation(translation);
      return;
    }

    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    _downloadingId = translation.id;
    _downloadStates[translation.id] = DownloadState.downloading;
    _downloadProgress[translation.id] = 0.0;
    notifyListeners();

    try {
      await _libraryRepository.downloadTranslation(
        translation.id,
        translation.url,
        cancelToken: _cancelToken,
        onProgress: (progress) {
          _downloadProgress[translation.id] = progress;
          notifyListeners();
        },
      );
      _downloadStates[translation.id] = DownloadState.ready;
      _downloadProgress.remove(translation.id);
      _selectedTranslation = translation;
      _downloadingId = null;
      _cancelToken = null;
      debugPrint('[OnboardingVM] Downloaded ${translation.id}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        debugPrint('[OnboardingVM] Download cancelled: ${translation.id}');
      } else {
        debugPrint('[OnboardingVM] Download error: $e');
      }
      _downloadStates[translation.id] = DownloadState.idle;
      _downloadProgress.remove(translation.id);
      _downloadingId = null;
      _cancelToken = null;
    } catch (e) {
      _downloadStates[translation.id] = DownloadState.idle;
      _downloadProgress.remove(translation.id);
      _downloadingId = null;
      _cancelToken = null;
      debugPrint('[OnboardingVM] Download error: $e');
    }

    notifyListeners();
  }

  void cancelTranslation() {
    if (_cancelToken != null && _downloadingId != null) {
      _cancelToken!.cancel();
      _downloadStates[_downloadingId!] = DownloadState.idle;
      _downloadProgress.remove(_downloadingId!);
      _downloadingId = null;
      _cancelToken = null;
      notifyListeners();
    }
  }
}
