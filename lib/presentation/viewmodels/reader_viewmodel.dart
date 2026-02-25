import 'package:flutter/foundation.dart';
import 'package:sola/core/models/page_model.dart';
import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

class ReaderViewModel extends ChangeNotifier {
  final RendererRepository _rendererRepository;
  final SessionRepository _sessionRepository;

  List<PageModel> _pages = [];
  int _currentPageIndex = 0;
  bool _isLoading = false;
  String? _currentCacheKey;
  String? _error;
  double _lastWidth = 0;
  double _lastHeight = 0;

  ReaderViewModel({
    required RendererRepository rendererRepository,
    required SessionRepository sessionRepository,
  }) : _rendererRepository = rendererRepository,
       _sessionRepository = sessionRepository;

  List<PageModel> get pages => _pages;
  int get currentPageIndex => _currentPageIndex;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPages(double width, double height) async {
    _lastWidth = width;
    _lastHeight = height;

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

  Future<void> navigateTo(String bookId, int pageNumber) async {
    debugPrint('[ReaderVM] navigateTo: book=$bookId page=$pageNumber');
    final currentBookId = _sessionRepository.currentSession.currentBookId;

    await _sessionRepository.setCurrentBook(bookId);
    await _sessionRepository.setCurrentPage(pageNumber);

    if (bookId != currentBookId) {
      _currentCacheKey = null;
      await loadPages(_lastWidth, _lastHeight);
    } else {
      _currentPageIndex = pageNumber.clamp(0, _pages.length - 1);
      notifyListeners();
    }
  }
}
