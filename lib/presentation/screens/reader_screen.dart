import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/reader_viewmodel.dart';
import '../viewmodels/search_viewmodel.dart';
import '../widgets/page_view_widget.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  PageController? _pageController;
  double? _lastWidth;
  double? _lastHeight;

  // Swipe-down search gesture state
  Offset? _startPosition;
  bool _isVerticalDrag = false;
  bool _hasDecidedDirection = false;
  static const _directionThreshold = 10.0;
  static const _verticalBias = 1.3;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _triggerLoad(double width, double height) {
    if (width == _lastWidth && height == _lastHeight) return;
    _lastWidth = width;
    _lastHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReaderViewModel>().loadPages(width, height);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<ReaderViewModel, SearchViewModel>(
        builder: (context, readerVm, searchVm, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final padding = MediaQuery.of(context).padding.top;
              final width = constraints.maxWidth - 2 * padding;
              final height = constraints.maxHeight - 2 * padding;

              _triggerLoad(width, height);

              if (readerVm.isLoading || readerVm.pages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              // Sync page controller
              if (_pageController == null ||
                  _pageController!.initialPage != readerVm.currentPageIndex) {
                _pageController?.dispose();
                _pageController = PageController(
                  initialPage: readerVm.currentPageIndex,
                );
              }

              return Listener(
                onPointerDown: (event) {
                  _startPosition = event.position;
                  _isVerticalDrag = false;
                  _hasDecidedDirection = false;
                },
                onPointerMove: (event) {
                  if (_startPosition == null) return;
                  if (_hasDecidedDirection) {
                    if (_isVerticalDrag) {
                      searchVm.handleDragUpdate(event.delta.dy);
                    }
                    return;
                  }
                  final delta = event.position - _startPosition!;
                  final distance = delta.distance;
                  if (distance < _directionThreshold) return;

                  _hasDecidedDirection = true;
                  _isVerticalDrag =
                      (delta.dy.abs() * _verticalBias) > delta.dx.abs() &&
                      delta.dy > 0;
                  if (_isVerticalDrag) {
                    setState(() {});
                  }
                },
                onPointerUp: (_) {
                  if (_isVerticalDrag) {
                    searchVm.handleDragEnd();
                  }
                  _startPosition = null;
                  _isVerticalDrag = false;
                  _hasDecidedDirection = false;
                  setState(() {});
                },
                child: AbsorbPointer(
                  absorbing: _isVerticalDrag,
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(padding),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: readerVm.pages.length,
                          onPageChanged: (i) => readerVm.setPage(i),
                          itemBuilder: (_, i) => PageViewWidget(
                            page: readerVm.pages[i],
                            width: width,
                            height: height,
                          ),
                        ),
                      ),
                      // Search icon indicator
                      Positioned(
                        top: searchVm.dragOffset + SearchViewModel.startDescent,
                        left: 0,
                        right: 0,
                        child: Opacity(
                          opacity:
                              (searchVm.dragOffset /
                                      SearchViewModel.triggerThreshold)
                                  .clamp(0.0, 1.0),
                          child: const Icon(
                            Icons.search,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      // SearchAnchor (invisible builder)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: SizedBox(
                          width: 0,
                          height: 0,
                          child: SearchAnchor(
                            searchController: searchVm.controller,
                            builder: (context, controller) =>
                                const SizedBox.shrink(),
                            suggestionsBuilder: (context, controller) {
                              final query = controller.text;
                              if (query.isEmpty) return [];
                              final result = searchVm.getResult(query);
                              if (result == null) return [];
                              return [
                                ListTile(
                                  title: Text(
                                    '${result.book} ${result.chapter}:${result.verse}',
                                  ),
                                  subtitle: Text('Page ${result.page + 1}'),
                                  onTap: () => searchVm.handleItemTap(
                                    result.book,
                                    result.page,
                                  ),
                                ),
                              ];
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
