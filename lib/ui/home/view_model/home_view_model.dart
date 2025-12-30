import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sola/data/repositories/library_repository.dart';
import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';
import 'package:sola/data/services/renderer_service.dart';
import 'package:sola/domain/models/bible_entry_model.dart';
import 'package:sola/domain/models/session_model.dart';

sealed class HomeState {}

class Loading extends HomeState {}

class Choosing extends HomeState {}

class Selected extends HomeState {
  final BibleEntryModel bible;
  Selected(this.bible);
}

class HomeViewModel extends ChangeNotifier {
  final SessionRepository sessionRepository;
  final LibraryRepository libraryRepository;
  final RendererService rendererService;

  HomeState _state = Loading();
  HomeState get state => _state;

  late String _currentTranslationId;
  late String _currentBookId;
  late int _currentPageNumber;
  String? _currentEmbeddingModelId;

  String? get currentTranslationId =>
      _state is Selected ? _currentTranslationId : null;
  String? get currentBookId => _state is Selected ? _currentBookId : null;
  int? get currentPageNumber => _state is Selected ? _currentPageNumber : null;

  HomeViewModel(
    this.sessionRepository,
    this.libraryRepository,
    this.rendererService,
  );

  Future<void> init() async {
    notifyListeners();
    rendererService.registerStyles();
    final session = await sessionRepository.loadSession();
    if (session != null) {
      _currentTranslationId = session.translationId;
      _currentBookId = session.bookId;
      _currentPageNumber = session.pageNumber;
      _currentEmbeddingModelId = session.embeddingModelId;
      try {
        final bible = await libraryRepository.getEntry(session.translationId);
        _state = Selected(bible);
      } catch (e) {
        print('Error loading previous translation: $e');
        _state = Choosing();
      }
    } else {
      _state = Choosing();
    }
    notifyListeners();
  }

  Future<List<BibleEntryModel>> getOptions() async {
    return await libraryRepository.getDownloadedEntries() +
        await libraryRepository.getNonDownloadedEntries();
  }

  Future<void> chooseOption(BibleEntryModel choice) async {
    _currentTranslationId = choice.id;
    _currentBookId = 'GEN';
    _currentPageNumber = 0;
    final session = SessionModel(
      translationId: _currentTranslationId,
      bookId: _currentBookId,
      pageNumber: _currentPageNumber,
      embeddingModelId: _currentEmbeddingModelId,
    );
    await sessionRepository.saveSession(session);
    _state = Selected(choice);
    notifyListeners();
  }

  Future<void> updateCurrentLocation(String bookId, int pageNumber) async {
    if (_state is Selected) {
      _currentBookId = bookId;
      _currentPageNumber = pageNumber;
      final session = SessionModel(
        translationId: _currentTranslationId,
        bookId: _currentBookId,
        pageNumber: _currentPageNumber,
        embeddingModelId: _currentEmbeddingModelId,
      );
      await sessionRepository.saveSession(session);
      notifyListeners();
    }
  }

  Future<void> updateEmbeddingModel(String modelId) async {
    _currentEmbeddingModelId = modelId;
    final session = SessionModel(
      translationId: _currentTranslationId,
      bookId: _currentBookId,
      pageNumber: _currentPageNumber,
      embeddingModelId: _currentEmbeddingModelId,
    );
    await sessionRepository.saveSession(session);
    notifyListeners();
  }

  Future<RendererRepository> getRenderer(
    BibleEntryModel bible,
    String book,
    double width,
    double height,
  ) async {
    print(book);
    final bibleRepository = await libraryRepository.getBible(
      rendererService,
      bible,
    );
    return await bibleRepository.getBook(book, width, height);
  }
}
