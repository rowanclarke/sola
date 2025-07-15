import 'package:flutter/material.dart';

class SearchViewModel extends ChangeNotifier {
  final SearchController controller = SearchController();
  Function(String item)? onItemSelected;

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

  void handleItemTap(String item) {
    onItemSelected?.call(item);
    controller.closeView(null);
  }
}
