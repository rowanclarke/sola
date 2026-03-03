import 'package:flutter/foundation.dart';
import 'package:sola/core/models/translation.dart';
import 'package:sola/data/repositories/bible_repository.dart';
import 'package:sola/data/repositories/index_repository.dart';
import 'package:sola/data/repositories/library_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

class LibraryViewModel extends ChangeNotifier {
  final LibraryRepository _libraryRepository;
  final SessionRepository _sessionRepository;
  final BibleRepository _bibleRepository;
  final IndexRepository _indexRepository;

  List<Translation> _availableTranslations = [];
  List<Translation> _downloadedTranslations = [];
  bool _isLoading = false;
  final Set<String> _downloadingIds = {};
  String? _error;

  LibraryViewModel({
    required LibraryRepository libraryRepository,
    required SessionRepository sessionRepository,
    required BibleRepository bibleRepository,
    required IndexRepository indexRepository,
  }) : _libraryRepository = libraryRepository,
       _sessionRepository = sessionRepository,
       _bibleRepository = bibleRepository,
       _indexRepository = indexRepository;

  List<Translation> get availableTranslations => _availableTranslations;
  List<Translation> get downloadedTranslations => _downloadedTranslations;
  bool get isLoading => _isLoading;
  bool get isDownloading => _downloadingIds.isNotEmpty;
  bool isDownloadingId(String id) => _downloadingIds.contains(id);
  String? get error => _error;

  Future<void> loadTranslations() async {
    debugPrint('[LibraryVM] Loading translations...');
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _availableTranslations = await _libraryRepository
          .getAvailableTranslations();
      _downloadedTranslations = await _libraryRepository
          .getDownloadedTranslations();
      debugPrint(
        '[LibraryVM] Loaded ${_availableTranslations.length} available, '
        '${_downloadedTranslations.length} downloaded',
      );
    } catch (e) {
      debugPrint('[LibraryVM] Load error: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> downloadTranslation(Translation translation) async {
    if (_downloadingIds.contains(translation.id)) return;
    debugPrint('[LibraryVM] Downloading ${translation.id}...');
    _downloadingIds.add(translation.id);
    _error = null;
    notifyListeners();
    try {
      await _libraryRepository.downloadTranslation(
        translation.id,
        translation.url,
      );
      await _bibleRepository.serializeTranslation(translation.id);
      _downloadedTranslations = await _libraryRepository
          .getDownloadedTranslations();
      final books = await _bibleRepository.getSerializedBooks(
        translationId: translation.id,
      );
      _indexRepository.indexBooks(translation.id, books);
      debugPrint('[LibraryVM] Download complete: ${translation.id}');
    } catch (e) {
      debugPrint('[LibraryVM] Download error (${translation.id}): $e');
      _error = e.toString();
    } finally {
      _downloadingIds.remove(translation.id);
      notifyListeners();
    }
  }

  Future<void> openTranslation(Translation translation) async {
    debugPrint('[LibraryVM] Opening translation: ${translation.id}');
    await _sessionRepository.setCurrentTranslation(translation.id);
  }

  Future<void> refresh() async {
    _libraryRepository.invalidateCache();
    await loadTranslations();
  }
}
