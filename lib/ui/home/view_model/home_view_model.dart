import 'package:flutter/foundation.dart';
import 'package:sola/data/repositories/bible_repository.dart';
import 'package:sola/data/repositories/library_repository.dart';
import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';
import 'package:sola/data/services/file_service.dart';
import 'package:sola/data/services/renderer_service.dart';
import 'package:sola/domain/models/bible_entry_model.dart';

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

  HomeViewModel(
    this.sessionRepository,
    this.libraryRepository,
    this.rendererService,
  );

  Future<void> init() async {
    notifyListeners();
    rendererService.registerStyles();
    final session = await sessionRepository.getSession();
    if (session != null) {
      _state = Selected(await libraryRepository.getEntry(session));
    } else {
      _state = Choosing();
    }
    notifyListeners();
  }

  Future<List<BibleEntryModel>> getOptions() async {
    return await libraryRepository.getNonDownloadedEntries();
  }

  Future<void> chooseOption(BibleEntryModel choice) async {
    sessionRepository.saveSession(choice.id);
    _state = Selected(choice);
    notifyListeners();
  }

  Future<RendererRepository> getRenderer(
    BibleEntryModel bible,
    String book,
    double width,
    double height,
  ) async {
    final bibleRepository = await libraryRepository.getBible(
      rendererService,
      bible,
    );
    return await bibleRepository.getBook(book, width, height);
  }
}
