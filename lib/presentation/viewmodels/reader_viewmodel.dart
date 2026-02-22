import 'package:flutter/foundation.dart';
import 'package:sola/core/models/page_model.dart';
import 'package:sola/data/repositories/bible_repository.dart';
import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

class ReaderViewModel extends ChangeNotifier {
  final RendererRepository _rendererRepository;
  final SessionRepository _sessionRepository;
  final BibleRepository _bibleRepository;

  List<PageModel> _pages = [];
  int _currentPageIndex = 0;
  bool _isLoading = false;
  String? _currentCacheKey;
  String? _error;

  ReaderViewModel({
    required RendererRepository rendererRepository,
    required SessionRepository sessionRepository,
    required BibleRepository bibleRepository,
  }) : _rendererRepository = rendererRepository,
       _sessionRepository = sessionRepository,
       _bibleRepository = bibleRepository;

  List<PageModel> get pages => _pages;
  int get currentPageIndex => _currentPageIndex;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPages(double width, double height) async {
    final translationId =
        _sessionRepository.currentSession.currentTranslationId;
    final bookId = _sessionRepository.currentSession.currentBookId;
    if (translationId == null || bookId == null) {
      debugPrint('[ReaderVM] No translation or book selected, skipping load');
      return;
    }

    final cacheKey = '$translationId/$bookId-$width-$height';
    if (cacheKey == _currentCacheKey) {
      debugPrint('[ReaderVM] Cache hit for $cacheKey, skipping load');
      return;
    }

    debugPrint('[ReaderVM] Loading pages: translation=$translationId book=$bookId '
        'size=${width.toInt()}x${height.toInt()}');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _bibleRepository.serializeTranslation(translationId);
      _pages = await _rendererRepository.renderAndLoadPages(
        translationId: translationId,
        bookId: bookId,
        width: width,
        height: height,
      );

      _currentCacheKey = cacheKey;
      final savedPage = _sessionRepository.currentSession.currentPageNumber ?? 0;
      _currentPageIndex = savedPage.clamp(0, _pages.length - 1);
      debugPrint('[ReaderVM] Loaded ${_pages.length} pages, starting at page $_currentPageIndex');
    } catch (e) {
      debugPrint('[ReaderVM] Error loading pages: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPage(int index) async {
    _currentPageIndex = index;
    await _sessionRepository.setCurrentPage(index);
    notifyListeners();
  }
}
