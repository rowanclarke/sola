import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sola/core/models/session_model.dart';
import 'package:sola/domain/services/file_service.dart';

class SessionRepository {
  final FileService _fileService;
  late SessionModel _currentSession;

  static const String _sessionFilePath = 'session.json';

  SessionRepository({required FileService fileService})
    : _fileService = fileService;

  SessionModel get currentSession => _currentSession;

  Future<void> init() async {
    debugPrint('[SessionRepo] Initializing...');
    _currentSession = await _loadSession();
    debugPrint('[SessionRepo] Session loaded: '
        'translation=${_currentSession.currentTranslationId} '
        'book=${_currentSession.currentBookId} '
        'page=${_currentSession.currentPageNumber}');
  }

  Future<void> setCurrentTranslation(String translationId) async {
    debugPrint('[SessionRepo] Setting translation: $translationId');
    _currentSession = _currentSession.copyWith(
      currentTranslationId: translationId,
      currentBookId: "GEN",
      currentPageNumber: 0,
    );
    await _persistSession();
  }

  Future<void> setCurrentBook(String bookId) async {
    debugPrint('[SessionRepo] Setting book: $bookId');
    _currentSession = _currentSession.copyWith(
      currentBookId: bookId,
      currentPageNumber: 0,
    );
    await _persistSession();
  }

  Future<void> setCurrentPage(int pageNumber) async {
    _currentSession = _currentSession.copyWith(currentPageNumber: pageNumber);
    await _persistSession();
  }

  Future<void> _persistSession() async {
    await _fileService.writeFile(
      _sessionFilePath,
      jsonEncode(_currentSession.toJson()),
    );
  }

  Future<SessionModel> _loadSession() async {
    try {
      final data = await _fileService.readFile(_sessionFilePath);
      return SessionModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      debugPrint('[SessionRepo] No existing session, using defaults');
      return const SessionModel();
    }
  }
}
