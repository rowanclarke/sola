import 'package:flutter/foundation.dart';
import 'package:sola/data/repositories/library_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';

sealed class HomeState {}

class Loading extends HomeState {}

class Choosing extends HomeState {}

class ShowingContent extends HomeState {
  final String content;
  ShowingContent(this.content);
}

class HomeViewModel extends ChangeNotifier {
  final SessionRepository sessionRepository;
  final LibraryRepository libraryReposotory;

  HomeState _state = Loading();
  HomeState get state => _state;

  HomeViewModel(this.sessionRepository, this.libraryReposotory);

  Future<void> init() async {
    notifyListeners();
    final session = await sessionRepository.getSession();
    if (session != null) {
      _state = ShowingContent(session);
    } else {
      _state = Choosing();
    }
    notifyListeners();
  }

  Future<List<String>> getOptions() async {
    print("Hi");
    return (await libraryReposotory.getNonDownloadedEntries())
        .map((d) => d.code)
        .toList();
  }

  Future<void> chooseOption(String choice) async {
    sessionRepository.saveSession(choice);
    _state = ShowingContent(choice);
    notifyListeners();
  }
}
