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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<ReaderViewModel>().loadPages(width, height);
      if (!mounted) return;
      context.read<SearchViewModel>().loadModel(); // fire-and-forget
    });
  }

  void _showSearchDialog(SearchViewModel searchVm) {
    showDialog(
      context: context,
      builder: (_) => _SearchDialog(searchVm: searchVm),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use screen size directly instead of LayoutBuilder constraints.
    // MediaQuery.sizeOf returns the logical screen dimensions, which are
    // invariant to keyboard visibility, overlays, and Scaffold resizing.
    // This prevents the Reader from re-rendering when the search keyboard opens.
    final screenSize = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final topPadding = safePadding.top;
    final width = screenSize.width - 2 * topPadding;
    final height = screenSize.height - 2 * topPadding;

    _triggerLoad(width, height);

    return Scaffold(
      // Keep body at full height when keyboard opens. The Reader has no text
      // inputs — the search dialog lives in the Overlay layer above.
      resizeToAvoidBottomInset: false,
      body: Consumer2<ReaderViewModel, SearchViewModel>(
        builder: (context, readerVm, searchVm, _) {
          if (readerVm.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  readerVm.error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

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
                final triggered = searchVm.handleDragEnd();
                if (triggered) {
                  _showSearchDialog(searchVm);
                }
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
                  PageView.builder(
                    controller: _pageController,
                    itemCount: readerVm.pages.length,
                    onPageChanged: (i) => readerVm.setPage(i),
                    itemBuilder: (_, i) => Padding(
                      padding: EdgeInsets.all(topPadding),
                      child: PageViewWidget(
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
                      opacity: (searchVm.dragOffset /
                              SearchViewModel.triggerThreshold)
                          .clamp(0.0, 1.0),
                      child: const Icon(
                        Icons.search,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchDialog extends StatefulWidget {
  final SearchViewModel searchVm;

  const _SearchDialog({required this.searchVm});

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Search verses...'),
            onSubmitted: (query) async {
              await widget.searchVm.getResult(query);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          if (widget.searchVm.error != null)
            Text(
              widget.searchVm.error!,
              style: const TextStyle(color: Colors.red),
            ),
          if (widget.searchVm.lastResult != null)
            ListTile(
              title: Text(
                '${widget.searchVm.lastResult!.book} '
                '${widget.searchVm.lastResult!.chapter}:'
                '${widget.searchVm.lastResult!.verse}',
              ),
              subtitle: Text('Page ${widget.searchVm.lastResult!.page + 1}'),
              onTap: () {
                widget.searchVm.handleItemTap(
                  widget.searchVm.lastResult!.book,
                  widget.searchVm.lastResult!.page,
                );
                Navigator.pop(context);
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
