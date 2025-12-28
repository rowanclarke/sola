import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sola/ui/home/view_model/home_view_model.dart';
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
            return LayoutBuilder(
              builder: (_, constraints) {
                final width = constraints.maxWidth - 2 * padding;
                final height = constraints.maxHeight - 2 * padding;
                if (width == 0 && height == 0) return Container();
                return FutureBuilder(
                  future: vm.getRenderer(bible, "GEN", width, height),
                  builder: (_, options) {
                    if (options.data != null) {
                      return ChangeNotifierProvider(
                        create: (_) =>
                            PaginationViewModel(options.data!)..init(),
                        child: PaginationScreen(padding, width, height),
                      );
                    } else {
                      return const Center(child: CircularProgressIndicator());
                    }
                  },
                );
              },
            );
        }
      },
    );
  }
}
