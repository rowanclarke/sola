import 'package:flutter/material.dart';
import 'package:sola/data/repositories/search_repository.dart';
import 'package:sola/domain/models/index_model.dart';

class SearchViewModel extends ChangeNotifier {
  final SearchController controller = SearchController();
  final SearchRepository repository;
  SearchViewModel(this.repository);

  Function(int)? onItemSelected;

  double dragOffset = 0.0;
  bool viewOpened = false;

  static const double startDescent = -50.0;
  static const double triggerThreshold = 125.0;
  static const double maxDescent = 150.0;

  void handleDragUpdate(DragUpdateDetails details) {
    dragOffset += details.delta.dy;
    if (dragOffset < 0) dragOffset = 0;
    notifyListeners();
  }

  void handleDragEnd(DragEndDetails details) {
    if (dragOffset > triggerThreshold) {
      controller.openView();
      viewOpened = true;
    }
    dragOffset = 0.0;
    notifyListeners();
  }

  void handleItemTap(int page) {
    onItemSelected?.call(page);
    controller.closeView(null);
  }

  Future<void> loadModel() async {
    await repository.loadModel();
  }

  Future<IndexModel> getResult(String s) async {
    return await repository.getResult(s);
  }
}
