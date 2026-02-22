import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/search_viewmodel.dart';
import '../widgets/search_result_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Consumer<SearchViewModel>(
        builder: (context, vm, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: 'Search verses...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _queryController.clear();
                      },
                    ),
                  ),
                  onSubmitted: (query) async {
                    await vm.getResult(query);
                  },
                ),
              ),
              if (vm.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    vm.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (vm.lastResult != null)
                SearchResultTile(
                  index: vm.lastResult!,
                  onTap: () {
                    vm.handleItemTap(
                      vm.lastResult!.book,
                      vm.lastResult!.page,
                    );
                    Navigator.pop(context);
                  },
                )
              else
                const Expanded(
                  child: Center(child: Text('Enter a search query')),
                ),
            ],
          );
        },
      ),
    );
  }
}
