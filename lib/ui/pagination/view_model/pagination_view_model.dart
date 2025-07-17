import 'package:flutter/material.dart';
import '../../../domain/models/page_model.dart';
import '../../../data/repositories/page_repository.dart';

class PaginationViewModel extends ChangeNotifier {
  final PageRepository repository;
  List<PageModel> _pages = [];
  int _currentIndex = 0;

  PaginationViewModel(this.repository);

  get initialized => repository.rendererRepository.initialized;

  List<PageModel> get pages => _pages;
  int get currentIndex => _currentIndex;

  Future<void> loadPages(double width, double height) async {
    print("Load Pages");
    _pages = await repository.getPages(width, height);
    notifyListeners();
  }

  void setPage(int index) {
    if (index >= 0 && index < _pages.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}
