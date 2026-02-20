import 'dart:convert';

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
    _currentSession = await _loadSession();
  }

  Future<void> setCurrentTranslation(String translationId) async {
    _currentSession = _currentSession.copyWith(
      currentTranslationId: translationId,
      currentBookId: "GEN",
      currentPageNumber: 0,
    );
    await _persistSession();
  }

  Future<void> setCurrentBook(String bookId) async {
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
      return const SessionModel();
    }
  }
}
