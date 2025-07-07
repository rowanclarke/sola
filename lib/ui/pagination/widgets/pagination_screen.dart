import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/pagination_view_model.dart';
import 'page_view_widget.dart';

class PaginationScreen extends StatelessWidget {
  final double padding;

  const PaginationScreen(this.padding, {super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PaginationViewModel>(
      builder: (context, vm, _) {
        return LayoutBuilder(
          builder: (_, constraints) {
            final width = constraints.maxWidth - 2.0 * padding;
            final height = constraints.maxHeight - 2.0 * padding;

            if (width == 0 && height == 0) return Container();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!vm.isLoading && vm.pages.isEmpty) {
                vm.loadPages(width, height);
              }
            });

            return PageView.builder(
              controller: PageController(),
              itemCount: vm.pages.length,
              onPageChanged: (index) {
                vm.setPage(index);
              },
              itemBuilder: (context, index) {
                final model = vm.pages[index];
                return Padding(
                  padding: EdgeInsets.all(padding),
                  child: PageViewWidget(
                    isLoading: vm.isLoading,
                    builder: model.page,
                    width: width,
                    height: height,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
