import 'package:flutter/material.dart';

const _ink = Color(0xFF18181b);
const _mid = Color(0xFF71717a);
const _fill = Color(0xFFF4F4F5);
const _line = Color(0xFFE4E4E7);

/// A search field + scrollable list, designed to be placed inside an
/// [Expanded] widget.  The generic [T] represents the item type — the
/// widget itself is model-agnostic, so any view-model that exposes a
/// filtered list and a search callback can drive it.
class SearchableListView<T> extends StatelessWidget {
  final String searchHint;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;

  const SearchableListView({
    super.key,
    required this.searchHint,
    required this.searchController,
    required this.onSearchChanged,
    required this.items,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: searchHint,
              hintStyle: const TextStyle(color: _mid, fontSize: 14),
              prefixIcon: const Icon(Icons.search, size: 18, color: _mid),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16, color: _mid),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _fill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _ink),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => itemBuilder(context, items[i]),
          ),
        ),
      ],
    );
  }
}
