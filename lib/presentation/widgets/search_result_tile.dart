import 'package:flutter/material.dart';
import 'package:rust/rust.dart' as rust;

class SearchResultTile extends StatelessWidget {
  final rust.Index index;
  final VoidCallback onTap;

  const SearchResultTile({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('${index.book} ${index.chapter}:${index.verse}'),
      subtitle: Text('Page ${index.page + 1}'),
      onTap: onTap,
    );
  }
}
