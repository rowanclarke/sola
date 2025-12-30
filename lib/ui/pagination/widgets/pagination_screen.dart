import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/pagination_view_model.dart';
import 'page_view_widget.dart';

class PaginationScreen extends StatefulWidget {
  final double padding;
  final double width;
  final double height;
  final int initialPage;

  const PaginationScreen(
    this.padding,
    this.width,
    this.height, {
    super.key,
    this.initialPage = 0,
  });

  @override
  State<PaginationScreen> createState() => _PaginationScreenState();
}

class _PaginationScreenState extends State<PaginationScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaginationViewModel>(
      builder: (context, vm, child) {
        switch (vm.state) {
          case Loading():
            return const Center(child: CircularProgressIndicator());
          case Viewing():
            return PageView.builder(
              controller: _pageController,
              itemCount: vm.pages.length,
              onPageChanged: (index) {
                vm.setPage(index);
              },
              itemBuilder: (context, index) {
                final model = vm.pages[index];
                return Padding(
                  padding: EdgeInsets.all(widget.padding),
                  child: PageViewWidget(
                    page: model.page,
                    width: widget.width,
                    height: widget.height,
                  ),
                );
              },
            );
        }
      },
    );
  }
}
