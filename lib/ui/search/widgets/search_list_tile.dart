import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sola/domain/models/index_model.dart';
import '../view_model/search_view_model.dart';

class SearchListTile extends StatelessWidget {
  final IndexModel index;
  const SearchListTile({required this.index, super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<SearchViewModel>();

    return ListTile(
      title: Text("${index.book} ${index.chapter}:${index.verse}"),
      onTap: () => vm.handleItemTap(index.book, index.page),
    );
  }
}
