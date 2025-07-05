import 'package:flutter/material.dart';
import '../../../domain/models/page_model.dart';
import '../../../data/repositories/page_repository.dart';

class PaginationViewModel extends ChangeNotifier {
  final PageRepository repository;
  List<PageModel> _pages = [];
  bool _isLoading = false;
  int _currentIndex = 0;

  PaginationViewModel({required this.repository});

  List<PageModel> get pages => _pages;
  bool get isLoading => _isLoading;
  int get currentIndex => _currentIndex;

  Future<void> loadPages() async {
    _isLoading = true;
    notifyListeners();

    _pages = await repository.getPages();

    _isLoading = false;
    notifyListeners();
  }

  void setPage(int index) {
    if (index >= 0 && index < _pages.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}
