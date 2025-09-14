import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/pagination_view_model.dart';
import 'page_view_widget.dart';

class PaginationScreen extends StatelessWidget {
  final double padding;
  final double width;
  final double height;

  const PaginationScreen(this.padding, this.width, this.height, {super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PaginationViewModel>(
      builder: (context, vm, child) {
        switch (vm.state) {
          case Loading():
            return const Center(child: CircularProgressIndicator());
          case Viewing():
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
                    page: model.page,
                    width: width,
                    height: height,
                  ),
                );
              },
            );
        }
      },
    );
  }
}
