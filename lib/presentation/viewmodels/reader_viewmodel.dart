import 'package:flutter/foundation.dart';
import 'package:sola/core/models/bible_books.dart';
import 'package:sola/core/models/page_model.dart';
import 'package:sola/data/repositories/session_repository.dart';

class ReaderViewModel extends ChangeNotifier {
  final SessionRepository _sessionRepository;

  List<PageModel> _pages = [];
  int _currentPageIndex = 0;
  bool _isLoading = false;
  String? _error;

  ReaderViewModel({
    required SessionRepository sessionRepository,
  }) : _sessionRepository = sessionRepository;

  List<PageModel> get pages => _pages;
  int get currentPageIndex => _currentPageIndex;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get currentBookId =>
      _sessionRepository.currentSession.currentBookId ?? 'GEN';

  Future<void> loadPages() async {
    final bookId = currentBookId;
    final book = BibleBooks.bookById(bookId);
    if (book == null) {
      debugPrint('[ReaderVM] Unknown book: $bookId');
      _error = 'Unknown book: $bookId';
      notifyListeners();
      return;
    }

    debugPrint('[ReaderVM] Loading pages for ${book.name} (${book.pageCount} pages)');
    _isLoading = true;
    _error = null;
    notifyListeners();

    _pages = List.generate(
      book.pageCount,
      (i) => PageModel(i + 1),
    );

    final savedPage =
        _sessionRepository.currentSession.currentPageNumber ?? 0;
    _currentPageIndex = savedPage.clamp(0, _pages.length - 1);
    debugPrint(
      '[ReaderVM] Loaded ${_pages.length} pages, starting at page $_currentPageIndex',
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setPage(int index) async {
    _currentPageIndex = index;
    await _sessionRepository.setCurrentPage(index);
    notifyListeners();
  }

  Future<void> navigateTo(String bookId, int pageNumber) async {
    debugPrint('[ReaderVM] navigateTo: book=$bookId page=$pageNumber');
    final currentBook = _sessionRepository.currentSession.currentBookId;

    await _sessionRepository.setCurrentBook(bookId);
    await _sessionRepository.setCurrentPage(pageNumber);

    if (bookId != currentBook) {
      await loadPages();
    } else {
      _currentPageIndex = pageNumber.clamp(0, _pages.length - 1);
      notifyListeners();
    }
  }
}
