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
  static const _horizontalPadding = 48.0;
  static const _verticalPadding = 16.0;

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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Consumer2<ReaderViewModel, SearchViewModel>(
          builder: (context, readerVm, searchVm, _) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _SearchBar(
                    focusNode: _searchFocusNode,
                    controller: _searchController,
                    searchVm: searchVm,
                  ),
                ),
                Expanded(
                  child: _buildReaderContent(readerVm, searchVm),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Placeholder',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
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
        final contentWidth = constraints.maxWidth - 2 * _horizontalPadding;
        final contentHeight = constraints.maxHeight - 2 * _verticalPadding;

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: _horizontalPadding,
                      vertical: _verticalPadding
                    ),
                    child: PageViewWidget(
                      page: readerVm.pages[i],
                      width: contentWidth,
                      height: contentHeight,
                    ),
                  ),
                ),
              ),
            ),
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
          ],
        );
      },
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
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _link = LayerLink();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _overlayController.show();
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

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (_) => _buildOverlayContent(vm),
        child: Container(
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
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              TextField(
                focusNode: widget.focusNode,
                controller: widget.controller,
                decoration: InputDecoration(
                  hintText: vm.isModelLoading
                      ? 'Loading...' : 'Search anything...',
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
                onChanged: (query) => vm.onQueryChanged(query),
                onTapOutside: (event) {
                  widget.focusNode.unfocus();
                },
              ),
              if (vm.isSearching)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayContent(SearchViewModel vm) {
    if (!_hasFocus || (vm.error == null && vm.lastResult == null)) {
      return const SizedBox.shrink();
    }

    final dropdownWidth = MediaQuery.sizeOf(context).width - 32;

    return CompositedTransformFollower(
      link: _link,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 4),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: dropdownWidth,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (vm.error != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                if (vm.lastResult != null)
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
                        vm.clearSearch();
                        widget.focusNode.unfocus();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
