import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sola/ui/home/view_model/home_view_model.dart';
import 'package:sola/ui/menu/view_model/menu_view_model.dart';
import 'package:sola/ui/menu/widgets/menu_screen.dart';
import 'package:sola/ui/pagination/view_model/pagination_view_model.dart'
    show PaginationViewModel;
import 'package:sola/ui/pagination/widgets/pagination_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, vm, child) {
        switch (vm.state) {
          case Loading():
            return const Center(child: CircularProgressIndicator());
          case Choosing():
            return FutureBuilder(
              future: vm.getOptions(),
              builder: (_, options) {
                if (options.data != null) {
                  return ListView(
                    children: options.data!
                        .map(
                          (opt) => ListTile(
                            title: Text(opt.id),
                            onTap: () async => await vm.chooseOption(opt),
                          ),
                        )
                        .toList(),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
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
                    future: vm.getRenderer(bible, bookId, width, height),
                    builder: (_, options) {
                      if (options.data != null) {
                        return ChangeNotifierProvider(
                          create: (_) => PaginationViewModel(
                            options.data!,
                            initialPage: initialPage,
                            onPageChanged: (pageNumber) {
                              vm.updateCurrentLocation(bookId, pageNumber);
                            },
                          )..init(),
                          child: PaginationScreen(
                            padding,
                            width,
                            height,
                            initialPage: initialPage,
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
