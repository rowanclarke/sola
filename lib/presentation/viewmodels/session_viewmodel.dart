import 'package:flutter/foundation.dart';
import 'package:sola/core/models/session_model.dart';
import 'package:sola/data/repositories/session_repository.dart';

class SessionViewModel extends ChangeNotifier {
  final SessionRepository _sessionRepository;

  SessionViewModel({required SessionRepository sessionRepository})
    : _sessionRepository = sessionRepository;

  SessionModel get currentSession => _sessionRepository.currentSession;
  String? get currentTranslationId => currentSession.currentTranslationId;
  String? get currentBookId => currentSession.currentBookId;
  int? get currentPageNumber => currentSession.currentPageNumber;

  void onSessionChanged() {
    notifyListeners();
  }
}
