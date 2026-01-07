import 'package:sola/core/models/session_model.dart';
import 'package:sola/core/session/session_state_data.dart';
import 'package:sola/domain/services/file_service.dart';

/// SessionRepository is the single source of truth for cross-screen application state.
/// It manages persistence and restoration of the current translation, book, and page.
/// All ViewModels access and modify global session state through this repository.
class SessionRepository {
  final FileService _fileService;
  late SessionModel _currentSession;

  /// Path where session state is persisted.
  static const String _sessionFilePath = 'session.json';

  SessionRepository({required FileService fileService})
    : _fileService = fileService;

  /// Returns the current session state.
  SessionModel get currentSession => _currentSession;

  /// Initializes the repository by loading persisted session state from storage.
  /// Called during application startup.
  Future<void> init() {
    throw UnimplementedError();
  }

  /// Updates the current translation ID in the session.
  /// Automatically persists the updated state.
  Future<void> setCurrentTranslation(String translationId) {
    throw UnimplementedError();
  }

  /// Updates the current book ID in the session.
  /// Automatically persists the updated state.
  Future<void> setCurrentBook(String bookId) {
    throw UnimplementedError();
  }

  /// Updates the current page number in the session.
  /// Automatically persists the updated state.
  Future<void> setCurrentPage(int pageNumber) {
    throw UnimplementedError();
  }

  /// Persists the current session state to storage.
  /// Called automatically after any session update.
  Future<void> _persistSession() {
    throw UnimplementedError();
  }

  /// Loads session state from storage.
  /// Returns a default empty session if no persisted data exists.
  Future<SessionModel> _loadSession() {
    throw UnimplementedError();
  }
}
