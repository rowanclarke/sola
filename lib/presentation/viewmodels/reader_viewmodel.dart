import 'package:flutter/foundation.dart';
import 'package:sola/core/models/page_model.dart';
import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

/// ReaderViewModel manages the display and navigation of rendered Bible pages.
/// Handles page changes, book navigation, and interaction with search.
class ReaderViewModel extends ChangeNotifier {
  final RendererRepository _rendererRepository;
  final SessionRepository _sessionRepository;

  PageModel? _currentPage;

  ReaderViewModel({
    required RendererRepository rendererRepository,
    required SessionRepository sessionRepository,
  }) : _rendererRepository = rendererRepository,
       _sessionRepository = sessionRepository;

  PageModel? get currentPage => _currentPage;

  /// Navigates to a specific page number and loads its content.
  /// Updates the session and notifies listeners.
  Future<void> goToPage(int pageNumber) {
    throw UnimplementedError();
  }

  /// Navigates to a specific book and its first page.
  Future<void> goToBook(String bookId) {
    throw UnimplementedError();
  }

  /// Navigates to the page containing a specific verse.
  /// Requires the verse reference to be resolved to a page number.
  Future<void> goToVerse(String verseReference) {
    throw UnimplementedError();
  }

  /// Opens the search screen overlay.
  void openSearch() {
    throw UnimplementedError();
  }

  /// Loads the current page content based on session state.
  Future<void> _loadCurrentPage() {
    throw UnimplementedError();
  }
}
