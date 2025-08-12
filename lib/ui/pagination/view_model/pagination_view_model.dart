import 'package:flutter/material.dart';
import '../../../domain/models/page_model.dart';
import '../../../data/repositories/page_repository.dart';

class PaginationViewModel extends ChangeNotifier {
  final PageRepository repository;
  final PageController controller = PageController();
  List<PageModel> _pages = [];

  PaginationViewModel(this.repository);

  get initialized => repository.rendererRepository.initialized;

  List<PageModel> get pages => _pages;

  Future<void> loadPages(String book, double width, double height) async {
    _pages = await repository.getPages(book, width, height);
    notifyListeners();
  }

  void jumpToPage(int index) {
    controller.jumpToPage(index);
  }

  void setPage(int index) {
    if (index >= 0 && index < _pages.length) {
      notifyListeners();
    }
  }
}
