import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/pagination_view_model.dart';
import 'page_view_widget.dart';

class PaginationScreen extends StatefulWidget {
  @override
  PaginationScreenState createState() => PaginationScreenState();
}

class PaginationScreenState extends State<PaginationScreen> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    final vm = context.read<PaginationViewModel>();
    vm.loadPages();
    _controller = PageController(initialPage: vm.currentIndex);
    _controller.addListener(_handleSwipe);
  }

  void _handleSwipe() {
    final vm = context.read<PaginationViewModel>();
    final page = _controller.page?.round() ?? vm.currentIndex;
    if (page != vm.currentIndex) {
      vm.setPage(page);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleSwipe);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaginationViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          appBar: AppBar(title: Text('Pagination Demo')),
          body: PageView.builder(
            controller: _controller,
            itemCount: vm.pages.length,
            itemBuilder: (context, index) {
              final model = vm.pages[index];
              return PageViewWidget(isLoading: vm.isLoading, text: model.text);
            },
          ),
        );
      },
    );
  }
}
