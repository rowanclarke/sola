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

  Future<void> loadPages(double width, double height) async {
    final translationId =
        _sessionRepository.currentSession.currentTranslationId;
    final bookId = _sessionRepository.currentSession.currentBookId;
    print("$translationId $bookId");
    if (translationId == null || bookId == null) return;

    final cacheKey = '$bookId-$width-$height';
    print("$cacheKey");
    if (cacheKey == _currentCacheKey) return;

    _isLoading = true;
    notifyListeners();

    print("Hiii");
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
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setPage(int index) async {
    _currentPageIndex = index;
    await _sessionRepository.setCurrentPage(index);
    notifyListeners();
  }
}
