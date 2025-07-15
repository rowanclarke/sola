import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/search_view_model.dart';
import 'search_list_tile.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();

    return Stack(
      children: [
        GestureDetector(
          onVerticalDragUpdate: vm.handleDragUpdate,
          onVerticalDragEnd: vm.handleDragEnd,
          child: Container(
            color: Colors.transparent,
            height: double.infinity,
            width: double.infinity,
          ),
        ),
        Positioned(
          top: SearchViewModel.startDescent,
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(
              0,
              vm.dragOffset.clamp(
                SearchViewModel.startDescent,
                SearchViewModel.maxDescent,
              ),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                ),
                child: Opacity(
                  opacity: (vm.dragOffset / SearchViewModel.triggerThreshold)
                      .clamp(0.0, 1.0),
                  child: Icon(
                    Icons.search,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
        Column(
          children: <Widget>[
            SearchAnchor(
              searchController: vm.controller,
              builder: (context, controller) => const SizedBox.shrink(),
              suggestionsBuilder: (context, controller) {
                return List.generate(5, (i) {
                  final item = 'item $i';
                  return SearchListTile(item: item);
                });
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: vm.controller.text.isEmpty
                  ? const Text('No item selected')
                  : Text('Selected item: ${vm.controller.text}'),
            ),
          ],
        ),
      ],
    );
  }
}
