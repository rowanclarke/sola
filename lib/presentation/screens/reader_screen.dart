import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/page_model.dart';
import '../../domain/services/book_pages.dart';
import '../../app/app_routes.dart';
import '../viewmodels/reader_viewmodel.dart';
import '../viewmodels/search_viewmodel.dart';
import '../viewmodels/translations_viewmodel.dart';
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
  BookPages? _lastBook;
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

  bool _loadTriggered = false;

  @override
  void initState() {
    super.initState();
    // The switcher chip needs to know what is downloaded before it can offer
    // anything; nothing else on this screen waits for it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TranslationsViewModel>().load();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _triggerLoad(double width, double height) {
    if (_loadTriggered) return;
    _loadTriggered = true;
    _lastWidth = width;
    _lastHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) => _runLoad(width, height));
  }

  /// Brings up everything that depends on the current translation, in the order
  /// the screen needs it.
  Future<void> _runLoad(double width, double height) async {
    if (!mounted) return;
    final readerVm = context.read<ReaderViewModel>();
    // The book being read comes first: it is all the reader needs to paint.
    // Page counts for the rest of the translation are only wanted by the
    // scrubber, and search only afterwards, so both run behind the reader.
    await readerVm.loadPages(width, height);
    if (!mounted) return;
    final bookIds = await readerVm.loadAll(width, height);
    if (!mounted) return;
    context.read<SearchViewModel>().initSearch(
      bookIds: bookIds,
      width: width,
      height: height,
    );
  }

  Future<void> _switchTranslation(String translationId) async {
    final width = _lastWidth;
    final height = _lastHeight;
    if (width == null || height == null) return;
    await context.read<ReaderViewModel>().prepareTranslationSwitch(
      translationId,
    );
    if (!mounted) return;
    // The chip reads the session, which has just moved under it.
    context.read<TranslationsViewModel>().refresh();
    await _runLoad(width, height);
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
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  // Base layer: reader content + scrubber below the panel
                  Column(
                    children: [
                      SizedBox(height: ReaderTopPanelState.panelHeight),
                      Expanded(
                        child: _buildReaderContent(readerVm, searchVm),
                      ),
                      ScrubberWidget(
                        currentGlobalPage: readerVm.currentGlobalPage,
                        bookData: readerVm.bookData,
                        onNavigate: (bookId, localPage) {
                          readerVm.navigateTo(bookId, localPage);
                        },
                      ),
                    ],
                  ),
                  // Top layer: panel paints last so pull-down overflow
                  // is visible above the reader content.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ReaderTopPanel(
                      key: _topPanelKey,
                      searchViewModel: searchVm,
                      onResultTap: (bookId, page) {
                        readerVm.navigateTo(bookId, page);
                      },
                      onSettingsTap: () => context.goToSettings(),
                      onTranslationSelected: _switchTranslation,
                      onManageTranslations: () =>
                          context.goToManageTranslations(),
                    ),
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

        final book = readerVm.book;
        if (book == null || book.pageCount == 0) {
          // Only the book being read has to be laid out before anything shows;
          // the rest of the translation renders behind the reader.
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

        if (readerVm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Detect if a different book was opened
        if (!identical(book, _lastBook)) {
          _lastBook = book;
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
              itemCount: book.pageCount,
              onPageChanged: (i) => readerVm.setPage(i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                  vertical: _verticalPadding,
                ),
                child: Center(
                  child: _PageSlot(
                    book: book,
                    index: i,
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

/// Holds one page for exactly as long as Flutter keeps its widget alive.
///
/// PageView builds the pages around the current one and disposes them once they
/// scroll out of range. That disposal is the signal that the rendered page can
/// go, so the slot pins its page on the way in and hands it back on the way
/// out — [BookPages] then keeps a few of the released ones and drops the rest.
class _PageSlot extends StatefulWidget {
  final BookPages book;
  final int index;
  final double width;
  final double height;

  const _PageSlot({
    required this.book,
    required this.index,
    required this.width,
    required this.height,
  });

  @override
  State<_PageSlot> createState() => _PageSlotState();
}

class _PageSlotState extends State<_PageSlot> {
  late PageModel _page;

  @override
  void initState() {
    super.initState();
    _page = _acquire(widget.book, widget.index);
  }

  @override
  void didUpdateWidget(_PageSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book != widget.book || oldWidget.index != widget.index) {
      oldWidget.book.release(oldWidget.index);
      _page = _acquire(widget.book, widget.index);
    }
  }

  PageModel _acquire(BookPages book, int index) {
    book.retain(index);
    final page = book.page(index);
    // Whichever way this page was reached, the next swipe is one either side.
    book.prefetchAround(index);
    return page;
  }

  @override
  void dispose() {
    widget.book.release(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageViewWidget(
      page: _page,
      width: widget.width,
      height: widget.height,
    );
  }
}
