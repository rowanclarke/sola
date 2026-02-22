import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart' as rust;
import 'package:sola/data/repositories/search_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

class SearchViewModel extends ChangeNotifier {
  final SearchRepository _searchRepository;
  final SessionRepository _sessionRepository;

  double dragOffset = 0.0;
  rust.Index? _lastResult;
  String? _error;

  static const double startDescent = -50.0;
  static const double triggerThreshold = 125.0;
  static const double maxDescent = 150.0;

  SearchViewModel({
    required SearchRepository searchRepository,
    required SessionRepository sessionRepository,
  }) : _searchRepository = searchRepository,
       _sessionRepository = sessionRepository;

  rust.Index? get lastResult => _lastResult;
  String? get error => _error;

  void handleDragUpdate(double deltaY) {
    dragOffset = (dragOffset + deltaY).clamp(0, maxDescent);
    notifyListeners();
  }

  bool handleDragEnd() {
    final triggered = dragOffset >= triggerThreshold;
    dragOffset = 0;
    notifyListeners();
    return triggered;
  }

  Future<void> loadModel() async {
    debugPrint('[SearchVM] Loading search model...');
    try {
      await _searchRepository.loadModel();
      debugPrint('[SearchVM] Model loaded');
    } catch (e) {
      debugPrint('[SearchVM] Model load error: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<rust.Index?> getResult(String query) async {
    if (query.isEmpty) return null;
    debugPrint('[SearchVM] Searching: "$query"');
    _error = null;
    try {
      _lastResult = _searchRepository.getResult(query);
      debugPrint('[SearchVM] Result: book=${_lastResult?.book} '
          'ch=${_lastResult?.chapter}:${_lastResult?.verse} page=${_lastResult?.page}');
    } catch (e) {
      debugPrint('[SearchVM] Search error: $e');
      _error = e.toString();
      _lastResult = null;
    }
    notifyListeners();
    return _lastResult;
  }

  Future<void> handleItemTap(String bookId, int pageNumber) async {
    debugPrint('[SearchVM] Navigating to book=$bookId page=$pageNumber');
    await _sessionRepository.setCurrentBook(bookId);
    await _sessionRepository.setCurrentPage(pageNumber);
  }
}
