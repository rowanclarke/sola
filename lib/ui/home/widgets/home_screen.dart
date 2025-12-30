import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sola/data/repositories/search_repository.dart';
import 'package:sola/ui/home/view_model/home_view_model.dart';
import 'package:sola/ui/menu/view_model/menu_view_model.dart';
import 'package:sola/ui/menu/widgets/menu_screen.dart';
import 'package:sola/ui/pagination/view_model/pagination_view_model.dart'
    show PaginationViewModel;
import 'package:sola/ui/pagination/widgets/pagination_screen.dart';
import 'package:sola/ui/search/view_model/search_view_model.dart';
import 'package:sola/ui/search/widgets/search_screen.dart';
import 'package:sola/ui/translation_selection/widgets/translation_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, vm, child) {
        switch (vm.state) {
          case Loading():
            return const Center(child: CircularProgressIndicator());
          case Welcome():
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Sola',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Read the Bible with semantic search',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TranslationSelectionScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Select Translation'),
                    ),
                  ],
                ),
              ),
            );
          case Selected(:final bible):
            final padding = MediaQuery.of(context).padding.top;
            return Scaffold(
              appBar: AppBar(
                title: Text(bible.id),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider(
                            create: (_) => MenuViewModel(),
                            child: const MenuScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              body: LayoutBuilder(
                builder: (_, constraints) {
                  final width = constraints.maxWidth - 2 * padding;
                  final height = constraints.maxHeight - 2 * padding;
                  if (width == 0 && height == 0) return Container();
                  final bookId = vm.currentBookId ?? "GEN";
                  final initialPage = vm.currentPageNumber ?? 0;
                  return FutureBuilder(
                    key: ValueKey('${bible.id}-$bookId'),
                    future: vm.getRenderer(bible, bookId, width, height),
                    builder: (_, options) {
                      if (options.data != null) {
                        final rendererRepository = options.data!;
                        final searchRepository = SearchRepository(
                          rendererRepository,
                          vm.modelService,
                          vm.searchService,
                        );
                        return MultiProvider(
                          providers: [
                            ChangeNotifierProvider(
                              create: (_) => SearchViewModel(
                                searchRepository,
                                onItemSelected: (bookId, pageNumber) {
                                  vm.updateCurrentLocation(bookId, pageNumber);
                                },
                              )..loadModel(),
                            ),
                            ChangeNotifierProvider(
                              create: (_) => PaginationViewModel(
                                rendererRepository,
                                initialPage: initialPage,
                                onPageChanged: (pageNumber) {
                                  vm.updateCurrentLocation(bookId, pageNumber);
                                },
                              )..init(),
                            ),
                          ],
                          child: SearchScreen(
                            child: PaginationScreen(
                              padding,
                              width,
                              height,
                              initialPage: initialPage,
                            ),
                          ),
                        );
                      } else {
                        return const Center(child: CircularProgressIndicator());
                      }
                    },
                  );
                },
              ),
            );
        }
      },
    );
  }
}
