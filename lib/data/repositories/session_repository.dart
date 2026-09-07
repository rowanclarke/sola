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

  Future<void> setCurrentLanguage(String code) async {
    debugPrint('[SessionRepo] Setting language: $code');
    _currentSession = _currentSession.copyWith(
      currentLanguageCode: code,
    );
    await _persistSession();
  }

  /// Starts a translation from the beginning. Used by onboarding and by adding
  /// a translation from settings, where there is no position worth keeping.
  Future<void> setCurrentTranslation(String translationId) async {
    debugPrint('[SessionRepo] Setting translation: $translationId');
    _currentSession = _currentSession.copyWith(
      currentTranslationId: translationId,
      currentBookId: "GEN",
      currentPageNumber: 0,
      switcherTranslationIds: _withInSwitcher(translationId),
    );
    await _persistSession();
  }

  /// Swaps the translation under the reader without leaving the book. Page
  /// breaks do not survive the swap, so the book restarts at its first page.
  Future<void> switchTranslation(
    String translationId, {
    required String bookId,
  }) async {
    debugPrint('[SessionRepo] Switching translation: $translationId ($bookId)');
    _currentSession = _currentSession.copyWith(
      currentTranslationId: translationId,
      currentBookId: bookId,
      currentPageNumber: 0,
      switcherTranslationIds: _withInSwitcher(translationId),
    );
    await _persistSession();
  }

  Future<void> setSwitcherTranslations(List<String> ids) async {
    debugPrint('[SessionRepo] Setting switcher translations: $ids');
    _currentSession = _currentSession.copyWith(
      switcherTranslationIds: List.unmodifiable(ids),
    );
    await _persistSession();
  }

  /// The switcher list with [translationId] guaranteed present: whatever is
  /// being read is always reachable from the switcher.
  List<String> _withInSwitcher(String translationId) {
    final ids = _currentSession.switcherTranslationIds;
    if (ids.contains(translationId)) return ids;
    return List.unmodifiable([...ids, translationId]);
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
