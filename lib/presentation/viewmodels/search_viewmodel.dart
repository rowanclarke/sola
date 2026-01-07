import 'package:flutter/foundation.dart';
import 'package:sola/core/models/book.dart' show VerseData;
import 'package:sola/data/repositories/search_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

/// SearchViewModel manages the search input and results.
/// Handles query entry and verse selection for navigation.
class SearchViewModel extends ChangeNotifier {
  final SearchRepository _searchRepository;
  final SessionRepository _sessionRepository;

  String _searchQuery = '';
  List<VerseData> _searchResults = [];
  bool _isSearching = false;

  SearchViewModel({
    required SearchRepository searchRepository,
    required SessionRepository sessionRepository,
  }) : _searchRepository = searchRepository,
       _sessionRepository = sessionRepository;

  String get searchQuery => _searchQuery;
  List<VerseData> get searchResults => _searchResults;
  bool get isSearching => _isSearching;

  /// Updates the search query and performs a search.
  /// Results are updated in _searchResults and listeners are notified.
  Future<void> performSearch(String query) {
    throw UnimplementedError();
  }

  /// Updates the search query without performing a search.
  /// Useful for debouncing search input.
  void updateQuery(String query) {
    throw UnimplementedError();
  }

  /// Navigates to a verse by updating the session state.
  /// The ReaderScreen observes session changes and navigates accordingly.
  Future<void> selectVerse(VerseData verse) {
    throw UnimplementedError();
  }

  /// Clears the search results and query.
  void clear() {
    throw UnimplementedError();
  }
}
