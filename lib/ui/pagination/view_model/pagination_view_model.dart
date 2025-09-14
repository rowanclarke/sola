import 'package:flutter/material.dart';
import 'package:sola/data/repositories/renderer_repository.dart';
import '../../../domain/models/page_model.dart';
import '../../../data/repositories/page_repository.dart';

sealed class PaginationState {}

class Loading extends PaginationState {}

class Viewing extends PaginationState {
  final int index;
  Viewing(this.index);
}

class PaginationViewModel extends ChangeNotifier {
  final RendererRepository repository;

  PaginationState _state = Loading();
  PaginationState get state => _state;

  late List<PageModel> pages;

  PaginationViewModel(this.repository);

  Future<void> init() async {
    notifyListeners();
    final texts = await Future.wait(
      List.generate(repository.numPages, (n) => repository.getPage(n)),
    );
    pages = texts.map((text) => PageModel(page: text)).toList();
    _state = Viewing(0);
    notifyListeners();
  }

  void setPage(int index) {
    if (index >= 0 && index < repository.numPages) {
      _state = Viewing(index);
      notifyListeners();
    }
  }
}
