import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/pagination_view_model.dart';
import 'page_view_widget.dart';

class PaginationScreen extends StatelessWidget {
  final double padding;
  final void Function(DragUpdateDetails)? onVerticalUpdate;
  final void Function(DragEndDetails)? onVerticalEnd;

  const PaginationScreen(
    this.padding, {
    super.key,
    this.onVerticalUpdate,
    this.onVerticalEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PaginationViewModel>(
      builder: (context, vm, _) {
        return LayoutBuilder(
          builder: (_, constraints) {
            final width = constraints.maxWidth - 2.0 * padding;
            final height = constraints.maxHeight - 2.0 * padding;

            if (width == 0 && height == 0) return Container();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!vm.isLoading && vm.pages.isEmpty) {
                vm.loadPages(width, height);
              }
            });

            return PageViewWithVerticalGestures(
              onVerticalUpdate: onVerticalUpdate,
              onVerticalEnd: onVerticalEnd,
              child: PageView.builder(
                controller: PageController(),
                hitTestBehavior: HitTestBehavior.translucent,
                itemCount: vm.pages.length,
                onPageChanged: (index) {
                  vm.setPage(index);
                },
                itemBuilder: (context, index) {
                  final model = vm.pages[index];
                  return Padding(
                    padding: EdgeInsets.all(padding),
                    child: PageViewWidget(
                      isLoading: vm.isLoading,
                      builder: model.page,
                      width: width,
                      height: height,
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class PageViewWithVerticalGestures extends StatefulWidget {
  final Widget child; // Your existing PageView
  final void Function(DragUpdateDetails)? onVerticalUpdate;
  final void Function(DragEndDetails)? onVerticalEnd;

  const PageViewWithVerticalGestures({
    super.key,
    required this.child,
    this.onVerticalUpdate,
    this.onVerticalEnd,
  });

  @override
  State<PageViewWithVerticalGestures> createState() =>
      _PageViewWithVerticalGesturesState();
}

class _PageViewWithVerticalGesturesState
    extends State<PageViewWithVerticalGestures> {
  Offset? _startPosition;
  Offset? _lastPosition;
  bool _isVerticalDrag = false;
  bool _hasDecidedDirection = false;
  bool _isTracking = false;

  static const double _directionThreshold = 10.0;
  static const double _verticalBias = 1.3;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AbsorbPointer(absorbing: _isVerticalDrag, child: widget.child),
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
        // Force a rebuild to absorb pointer events from PageView
        setState(() {});
      }
    }

    if (_hasDecidedDirection &&
        _isVerticalDrag &&
        widget.onVerticalUpdate != null) {
      final lastPos = _lastPosition ?? _startPosition!;
      final moveDelta = event.position - lastPos;

      widget.onVerticalUpdate!(
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
    if (_isTracking && _isVerticalDrag && widget.onVerticalEnd != null) {
      final velocity = Velocity(
        pixelsPerSecond: Offset(
          event.delta.dx / event.timeStamp.inMilliseconds,
          event.delta.dy / event.timeStamp.inMilliseconds,
        ),
      );

      // Create DragEndDetails manually
      final dragEndDetails = DragEndDetails(
        velocity: velocity,
        primaryVelocity: velocity.pixelsPerSecond.dy, // or dx for horizontal
      );

      widget.onVerticalEnd!(dragEndDetails);
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
}
