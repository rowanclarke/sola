import 'package:flutter/foundation.dart';
import 'package:sola/core/models/session_model.dart';
import 'package:sola/data/repositories/session_repository.dart';

/// SessionViewModel provides observable access to the global application session state.
/// Exposes the current translation, book, and page for use across the application.
/// Listens to changes in the SessionRepository and notifies subscribers.
class SessionViewModel extends ChangeNotifier {
  final SessionRepository _sessionRepository;

  SessionViewModel({required SessionRepository sessionRepository})
    : _sessionRepository = sessionRepository;

  /// Returns the current session state.
  SessionModel get currentSession => _sessionRepository.currentSession;

  /// Returns the current translation ID, or null if none is set.
  String? get currentTranslationId => currentSession.currentTranslationId;

  /// Returns the current book ID, or null if none is set.
  String? get currentBookId => currentSession.currentBookId;

  /// Returns the current page number, or null if none is set.
  int? get currentPageNumber => currentSession.currentPageNumber;

  /// Notifies listeners of session state changes.
  /// Called internally when the repository's state changes.
  void onSessionChanged() {
    throw UnimplementedError();
  }
}
