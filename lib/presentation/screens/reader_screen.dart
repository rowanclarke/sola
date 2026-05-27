import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/page_model.dart';
import '../viewmodels/reader_viewmodel.dart';
import '../viewmodels/search_viewmodel.dart';
import '../widgets/page_view_widget.dart';
import '../widgets/reader_top_panel.dart';
import '../widgets/scrubber_widget.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  PageController _pageController = PageController();
  List<PageModel>? _lastPages;
  Key _pageViewKey = UniqueKey();
  double? _lastWidth;
  double? _lastHeight;

  final GlobalKey<ReaderTopPanelState> _topPanelKey = GlobalKey();

  // Swipe-down search gesture state (full-page)
  Offset? _startPosition;
  bool _isVerticalDrag = false;
  bool _hasDecidedDirection = false;
  double _dragOffset = 0;
  static const _directionThreshold = 10.0;
  static const _verticalBias = 1.3;
  static const _horizontalPadding = 48.0;
  static const _verticalPadding = 16.0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _triggerLoad(double width, double height) {
    if (_lastWidth != null && _lastHeight != null) return;
    _lastWidth = width;
    _lastHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final bookIds = await context.read<ReaderViewModel>().loadAll(
        width,
        height,
      );
      if (!mounted) return;
      await context.read<ReaderViewModel>().loadPages(width, height);
      if (!mounted) return;
      context.read<SearchViewModel>().initSearch(
        bookIds: bookIds,
        width: width,
        height: height,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Consumer2<ReaderViewModel, SearchViewModel>(
          builder: (context, readerVm, searchVm, _) {
            return GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Column(
                children: [
                  ReaderTopPanel(
                    key: _topPanelKey,
                    searchViewModel: searchVm,
                    onResultTap: (bookId, page) {
                      readerVm.navigateTo(bookId, page);
                    },
                  ),
                  Expanded(child: _buildReaderContent(readerVm, searchVm)),
                  ScrubberWidget(
                    currentGlobalPage: readerVm.currentGlobalPage,
                    bookData: readerVm.bookData,
                    onNavigate: (bookId, localPage) {
                      readerVm.navigateTo(bookId, localPage);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReaderContent(
    ReaderViewModel readerVm,
    SearchViewModel searchVm,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = (constraints.maxWidth - 2 * _horizontalPadding)
            .floorToDouble();
        final contentHeight = (constraints.maxHeight - 2 * _verticalPadding)
            .floorToDouble();

        _triggerLoad(contentWidth, contentHeight);

        if (readerVm.isRendering) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Rendering'),
              ],
            ),
          );
        }

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

        // Detect if pages array changed (new book loaded)
        if (!identical(readerVm.pages, _lastPages)) {
          _lastPages = readerVm.pages;
          _pageController.dispose();
          _pageController = PageController(
            initialPage: readerVm.currentPageIndex,
          );
          _pageViewKey = UniqueKey();
        }

        // Handle same-book page jump (navigateTo or search result tap)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          if (_pageController.page?.round() != readerVm.currentPageIndex) {
            _pageController.jumpToPage(readerVm.currentPageIndex);
          }
        });

        // Listener wraps the PageView to detect full-page vertical drags
        return Listener(
          onPointerDown: (event) {
            _startPosition = event.position;
            _isVerticalDrag = false;
            _hasDecidedDirection = false;
            _dragOffset = 0;
          },
          onPointerMove: (event) {
            if (_startPosition == null) return;
            if (_hasDecidedDirection) {
              if (_isVerticalDrag) {
                _dragOffset += event.delta.dy;
                _topPanelKey.currentState?.handleDragUpdate(_dragOffset);
              }
              return;
            }
            final delta = event.position - _startPosition!;
            if (delta.distance < _directionThreshold) return;

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
              _topPanelKey.currentState?.handleDragEnd();
            }
            _startPosition = null;
            _isVerticalDrag = false;
            _hasDecidedDirection = false;
            _dragOffset = 0;
            setState(() {});
          },
          child: AbsorbPointer(
            absorbing: _isVerticalDrag,
            child: PageView.builder(
              key: _pageViewKey,
              controller: _pageController,
              itemCount: readerVm.pages.length,
              onPageChanged: (i) => readerVm.setPage(i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                  vertical: _verticalPadding,
                ),
                child: Center(
                  child: PageViewWidget(
                    page: readerVm.pages[i],
                    width: contentWidth,
                    height: contentHeight,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
