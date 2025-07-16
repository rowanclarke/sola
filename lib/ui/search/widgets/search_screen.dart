import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sola/ui/search/widgets/search_anchor.dart';
import '../view_model/search_view_model.dart';
import 'search_list_tile.dart';

class SearchScreen extends StatefulWidget {
  final Widget child;

  const SearchScreen({super.key, required this.child});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Offset? _startPosition;
  Offset? _lastPosition;
  bool _isVerticalDrag = false;
  bool _hasDecidedDirection = false;
  bool _isTracking = false;

  static const double _directionThreshold = 10.0;
  static const double _verticalBias = 1.3;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AbsorbPointer(
        absorbing: _isVerticalDrag,
        child: Stack(
          children: [
            widget.child,
            Positioned(
              top: SearchViewModel.startDescent,
              left: 0,
              right: 0,
              child: Transform.translate(
                offset: Offset(
                  0,
                  vm.dragOffset.clamp(
                    SearchViewModel.startDescent,
                    SearchViewModel.maxDescent,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: Opacity(
                      opacity:
                          (vm.dragOffset / SearchViewModel.triggerThreshold)
                              .clamp(0.0, 1.0),
                      child: Icon(
                        Icons.search,
                        size: 20,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AsyncSearchAnchor<String>(
              searchController: vm.controller,
              searchFunction: (query) async => [await vm.getResult(query)],
              builder: (result) => SearchListTile(item: result),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _startPosition = event.position;
    _lastPosition = event.position;
    _isVerticalDrag = false;
    _hasDecidedDirection = false;
    _isTracking = true;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isTracking || _startPosition == null) return;

    final delta = event.position - _startPosition!;

    // Decide direction once we have enough movement
    if (!_hasDecidedDirection && delta.distance > _directionThreshold) {
      _hasDecidedDirection = true;
      _isVerticalDrag = (delta.dy.abs() * _verticalBias) > delta.dx.abs();

      if (_isVerticalDrag) {
        // Force a rebuild to absorb pointer events from child
        setState(() {});
      }
    }

    if (_hasDecidedDirection && _isVerticalDrag) {
      final lastPos = _lastPosition ?? _startPosition!;
      final moveDelta = event.position - lastPos;

      _handleVerticalUpdate(
        DragUpdateDetails(
          delta: moveDelta,
          globalPosition: event.position,
          localPosition: event.localPosition,
        ),
      );
    }

    _lastPosition = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_isTracking && _isVerticalDrag) {
      final velocity = Velocity(
        pixelsPerSecond: Offset(
          event.delta.dx / event.timeStamp.inMilliseconds,
          event.delta.dy / event.timeStamp.inMilliseconds,
        ),
      );

      final dragEndDetails = DragEndDetails(
        velocity: velocity,
        primaryVelocity: velocity.pixelsPerSecond.dy,
      );

      _handleVerticalEnd(dragEndDetails);
    }
    _reset();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _reset();
  }

  void _reset() {
    final wasVerticalDrag = _isVerticalDrag;
    _isTracking = false;
    _startPosition = null;
    _lastPosition = null;
    _isVerticalDrag = false;
    _hasDecidedDirection = false;

    if (wasVerticalDrag) {
      setState(() {}); // Stop absorbing pointer events
    }
  }

  void _handleVerticalUpdate(DragUpdateDetails details) {
    final vm = context.read<SearchViewModel>();
    vm.handleDragUpdate(details);
  }

  void _handleVerticalEnd(DragEndDetails details) {
    final vm = context.read<SearchViewModel>();
    vm.handleDragEnd(details);
  }
}
