import 'package:flutter/foundation.dart';
import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';
import 'package:sola/domain/services/book_pages.dart';

class ReaderViewModel extends ChangeNotifier {
  final RendererRepository _rendererRepository;
  final SessionRepository _sessionRepository;

  BookPages? _book;
  int _currentPageIndex = 0;
  bool _isLoading = false;
  bool _isRendering = false;
  String? _currentCacheKey;
  String? _error;
  double _lastWidth = 0;
  double _lastHeight = 0;
  Map<String, BookData> _bookData = {};

  ReaderViewModel({
    required RendererRepository rendererRepository,
    required SessionRepository sessionRepository,
  }) : _rendererRepository = rendererRepository,
       _sessionRepository = sessionRepository;

  /// The open book, or null before the first load. Pages come off it one at a
  /// time; nothing here holds the whole book.
  BookPages? get book => _book;
  int get pageCount => _book?.pageCount ?? 0;
  int get currentPageIndex => _currentPageIndex;
  bool get isLoading => _isLoading;
  bool get isRendering => _isRendering;
  String? get error => _error;
  Map<String, BookData> get bookData => _bookData;

  String get currentBookId =>
      _sessionRepository.currentSession.currentBookId ?? 'GEN';

  int get currentGlobalPage {
    int offset = 0;
    for (final entry in _bookData.entries) {
      if (entry.key == currentBookId) {
        return offset + _currentPageIndex;
      }
      offset += entry.value.pageCount;
    }
    return 0;
  }

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

    final cacheKey =
        '$translationId/$bookId-${width.toInt()}-${height.toInt()}';
    if (cacheKey == _currentCacheKey) {
      debugPrint('[ReaderVM] Cache hit for $cacheKey, skipping load');
      return;
    }

    debugPrint(
      '[ReaderVM] Loading pages: translation=$translationId book=$bookId '
      'size=${width.toInt()}x${height.toInt()}',
    );
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final book = await _rendererRepository.openBook(
        translationId: translationId,
        bookId: bookId,
        width: width,
        height: height,
      );

      _currentCacheKey = cacheKey;
      final savedPage =
          _sessionRepository.currentSession.currentPageNumber ?? 0;
      _currentPageIndex =
          book.pageCount == 0 ? 0 : savedPage.clamp(0, book.pageCount - 1);
      // Only the page being opened and the two either side of it are read;
      // the rest of the book stays on disk until it is swiped to.
      book.warm(_currentPageIndex);
      _book = book;
      debugPrint(
        '[ReaderVM] Opened book of ${book.pageCount} pages, '
        'starting at page $_currentPageIndex',
      );
    } catch (e) {
      debugPrint('[ReaderVM] Error loading pages: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<String>> loadAll(double width, double height) async {
    final translationId =
        _sessionRepository.currentSession.currentTranslationId;
    if (translationId == null) {
      debugPrint('[ReaderVM] No translation selected, skipping load');
      return [];
    }
    _isRendering = true;
    notifyListeners();
    try {
      final result = await _rendererRepository.renderAll(
        translationId: translationId,
        width: width,
        height: height,
      );
      _bookData = result;
      return result.keys.toList();
    } catch (e) {
      debugPrint('[ReaderVM] Error loading pages: $e');
      _error = e.toString();
      return [];
    } finally {
      _isRendering = false;
      notifyListeners();
    }
  }

  Future<void> setPage(int index) async {
    _currentPageIndex = index;
    _book?.prefetchAround(index);
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
      _currentPageIndex = pageCount == 0 ? 0 : pageNumber.clamp(0, pageCount - 1);
      // A jump lands somewhere the reader has not been: read the target and
      // its neighbours so the swipe away from it is ready too.
      _book?.warm(_currentPageIndex);
      notifyListeners();
    }
  }
}
