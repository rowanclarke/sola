import 'package:flutter/material.dart';
import 'package:sola/core/models/index.dart';

class SearchResultTile extends StatelessWidget {
  final Index index;
  final VoidCallback onTap;

  const SearchResultTile({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(index.reference),
      subtitle: Text('Page ${index.page + 1}'),
      onTap: onTap,
    );
  }
}
