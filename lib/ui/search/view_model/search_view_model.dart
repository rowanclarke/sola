import 'package:flutter/material.dart';

class SearchViewModel extends ChangeNotifier {
  final List<String> _allItems = List.generate(100, (i) => 'Item $i');
  List<String> _results = [];
  String _query = '';

  List<String> get results => _results;
  String get query => _query;

  void updateQuery(String query) {
    _query = query;
    _results = _allItems
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();
    notifyListeners();
  }

  void clear() {
    _query = '';
    _results = [];
    notifyListeners();
  }
}

