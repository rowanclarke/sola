import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/bible_books.dart';
import '../viewmodels/reader_viewmodel.dart';
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
  List<Object>? _lastPages;
  Key _pageViewKey = UniqueKey();

  final GlobalKey<ReaderTopPanelState> _topPanelKey = GlobalKey();

  // Swipe-down search gesture state (full-page)
  Offset? _startPosition;
  bool _isVerticalDrag = false;
  bool _hasDecidedDirection = false;
  double _dragOffset = 0;
  static const _directionThreshold = 10.0;
  static const _verticalBias = 1.3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReaderViewModel>().loadPages();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Consumer<ReaderViewModel>(
          builder: (context, readerVm, _) {
            return GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Column(
                children: [
                  ReaderTopPanel(key: _topPanelKey),
                  Expanded(child: _buildReaderContent(readerVm)),
                  ScrubberWidget(
                    currentGlobalPage: BibleBooks.bookToGlobalPage(
                      readerVm.currentBookId,
                      readerVm.currentPageIndex,
                    ),
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

  Widget _buildReaderContent(ReaderViewModel readerVm) {
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

    // Handle same-book page jump
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
          final triggered =
              _topPanelKey.currentState?.handleDragEnd() ?? false;
          if (triggered) {
            // search was activated
          }
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
            padding:
                const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            child: Center(
              child: PageViewWidget(
                page: readerVm.pages[i],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
