import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/page_model.dart';
import '../viewmodels/reader_viewmodel.dart';
import '../viewmodels/search_viewmodel.dart';
import '../widgets/page_view_widget.dart';

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

  // Search bar state
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  // Swipe-down search gesture state
  Offset? _startPosition;
  bool _isVerticalDrag = false;
  bool _hasDecidedDirection = false;
  static const _directionThreshold = 10.0;
  static const _verticalBias = 1.3;

  @override
  void dispose() {
    _pageController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final topPadding = safePadding.top;
    final width = screenSize.width - 2 * topPadding;
    final height = screenSize.height - 2 * topPadding;

    _triggerLoad(width, height);

    return Scaffold(
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

          // Detect if pages array changed (new book loaded)
          if (!identical(readerVm.pages, _lastPages)) {
            _lastPages = readerVm.pages;
            _pageController.dispose();
            _pageController =
                PageController(initialPage: readerVm.currentPageIndex);
            _pageViewKey = UniqueKey();
          }

          // Handle same-book page jump (navigateTo or search result tap)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_pageController.hasClients) return;
            if (_pageController.page?.round() != readerVm.currentPageIndex) {
              _pageController.jumpToPage(readerVm.currentPageIndex);
            }
          });

          return Stack(
            children: [
              // Layer 1: Reader content with swipe gesture
              Listener(
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
                      _searchFocusNode.requestFocus();
                    }
                  }
                  _startPosition = null;
                  _isVerticalDrag = false;
                  _hasDecidedDirection = false;
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
                      padding: EdgeInsets.all(topPadding),
                      child: PageViewWidget(
                        page: readerVm.pages[i],
                        width: width,
                        height: height,
                      ),
                    ),
                  ),
                ),
              ),

              // Layer 2: Swipe-down search icon indicator
              Positioned(
                top: searchVm.dragOffset + SearchViewModel.startDescent,
                left: 0,
                right: 0,
                child: IgnorePointer(
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
              ),

              // Layer 3: Search bar at top
              Positioned(
                top: topPadding + 8,
                left: 16,
                right: 16,
                child: _SearchBar(
                  focusNode: _searchFocusNode,
                  controller: _searchController,
                  searchVm: searchVm,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final SearchViewModel searchVm;

  const _SearchBar({
    required this.focusNode,
    required this.controller,
    required this.searchVm,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = widget.focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.searchVm;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search input
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            focusNode: widget.focusNode,
            controller: widget.controller,
            decoration: InputDecoration(
              hintText: 'Search verses...',
              prefixIcon: vm.isModelLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search),
              suffixIcon: _hasFocus
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        widget.controller.clear();
                        widget.focusNode.unfocus();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onSubmitted: (query) async {
              final result = await vm.getResult(query);
              if (result != null) {
                setState(() {});
              }
            },
          ),
        ),

        // Search result (shown below the bar when focused and result exists)
        if (_hasFocus && vm.error != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              vm.error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),

        if (_hasFocus && vm.lastResult != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                '${vm.lastResult!.book} '
                '${vm.lastResult!.chapter}:'
                '${vm.lastResult!.verse}',
              ),
              subtitle: Text('Page ${vm.lastResult!.page + 1}'),
              trailing: const Icon(Icons.arrow_forward, size: 18),
              onTap: () {
                context.read<ReaderViewModel>().navigateTo(
                  vm.lastResult!.book,
                  vm.lastResult!.page,
                );
                widget.controller.clear();
                widget.focusNode.unfocus();
              },
            ),
          ),
      ],
    );
  }
}
