import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/search_view_model.dart';

class SearchListTile extends StatelessWidget {
  final String item;
  const SearchListTile({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<SearchViewModel>();

    return ListTile(title: Text(item), onTap: () => vm.handleItemTap(item));
  }
}
