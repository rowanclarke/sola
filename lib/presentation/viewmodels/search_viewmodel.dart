import 'package:flutter/material.dart';
import 'package:rust/rust.dart' as rust;
import 'package:sola/data/repositories/search_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

class SearchViewModel extends ChangeNotifier {
  final SearchRepository _searchRepository;
  final SessionRepository _sessionRepository;

  SearchController controller = SearchController();
  double dragOffset = 0.0;
  rust.Index? _lastResult;

  static const double startDescent = -50.0;
  static const double triggerThreshold = 125.0;
  static const double maxDescent = 150.0;

  SearchViewModel({
    required SearchRepository searchRepository,
    required SessionRepository sessionRepository,
  }) : _searchRepository = searchRepository,
       _sessionRepository = sessionRepository;

  rust.Index? get lastResult => _lastResult;

  void handleDragUpdate(double deltaY) {
    dragOffset = (dragOffset + deltaY).clamp(0, maxDescent);
    notifyListeners();
  }

  void handleDragEnd() {
    if (dragOffset >= triggerThreshold) {
      controller.openView();
    }
    dragOffset = 0;
    notifyListeners();
  }

  Future<void> loadModel() async {
    await _searchRepository.loadModel();
  }

  rust.Index? getResult(String query) {
    if (query.isEmpty) return null;
    _lastResult = _searchRepository.getResult(query);
    notifyListeners();
    return _lastResult;
  }

  Future<void> handleItemTap(String bookId, int pageNumber) async {
    await _sessionRepository.setCurrentBook(bookId);
    await _sessionRepository.setCurrentPage(pageNumber);
    controller.closeView(null);
  }
}
