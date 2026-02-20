import 'package:flutter/foundation.dart';
import 'package:sola/core/models/translation.dart';
import 'package:sola/data/repositories/library_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

class LibraryViewModel extends ChangeNotifier {
  final LibraryRepository _libraryRepository;
  final SessionRepository _sessionRepository;

  List<Translation> _availableTranslations = [];
  List<Translation> _downloadedTranslations = [];
  bool _isLoading = false;
  bool _isDownloading = false;
  String? _downloadingTranslationId;

  LibraryViewModel({
    required LibraryRepository libraryRepository,
    required SessionRepository sessionRepository,
  }) : _libraryRepository = libraryRepository,
       _sessionRepository = sessionRepository;

  List<Translation> get availableTranslations => _availableTranslations;
  List<Translation> get downloadedTranslations => _downloadedTranslations;
  bool get isLoading => _isLoading;
  bool get isDownloading => _isDownloading;
  String? get downloadingTranslationId => _downloadingTranslationId;

  Future<void> loadTranslations() async {
    _isLoading = true;
    notifyListeners();
    _availableTranslations = await _libraryRepository
        .getAvailableTranslations();
    _downloadedTranslations = await _libraryRepository
        .getDownloadedTranslations();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> downloadTranslation(Translation translation) async {
    _isDownloading = true;
    _downloadingTranslationId = translation.id;
    notifyListeners();
    await _libraryRepository.downloadTranslation(
      translation.id,
      translation.url,
    );
    _downloadedTranslations = await _libraryRepository
        .getDownloadedTranslations();
    _isDownloading = false;
    _downloadingTranslationId = null;
    notifyListeners();
  }

  Future<void> openTranslation(Translation translation) async {
    await _sessionRepository.setCurrentTranslation(translation.id);
  }

  Future<void> refresh() async {
    _libraryRepository.invalidateCache();
    await loadTranslations();
  }
}
