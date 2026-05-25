import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/models/bible_books.dart';

/// Windowed edge-autoscroll scrubber.
///
/// Resting: page label centered, no visible strip.
/// Press-hold 180ms (or drag >8px): strip rises, 20-page window with book labels.
/// Edge zones auto-scroll at velocity tiers.
/// Release commits position via [onNavigate].
class ScrubberWidget extends StatefulWidget {
  final int currentGlobalPage;
  final void Function(String bookId, int localPage) onNavigate;

  const ScrubberWidget({
    super.key,
    required this.currentGlobalPage,
    required this.onNavigate,
  });

  @override
  State<ScrubberWidget> createState() => _ScrubberWidgetState();
}

class _ScrubberWidgetState extends State<ScrubberWidget>
    with SingleTickerProviderStateMixin {
  static const int _visiblePages = 20;
  static const double _stripHeight = 36;
  static const double _activeRaise = 0;

  bool _active = false;
  double _winStart = 0;
  double _thumbRatio = 0.5;
  double _idx = 0;
  int _velocityDir = 0;
  double _velocityMag = 0;

  Timer? _holdTimer;
  late final Ticker _ticker;
  bool _tickerRunning = false;
  Duration? _lastTickTime;
  Offset? _pointerStart;

  // Strip layout key for getting its global position
  final GlobalKey _stripKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _idx = widget.currentGlobalPage.toDouble();
    _centerWindow();
  }

  @override
  void didUpdateWidget(ScrubberWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_active && widget.currentGlobalPage != oldWidget.currentGlobalPage) {
      _idx = widget.currentGlobalPage.toDouble();
      _centerWindow();
    }
  }

  void _centerWindow() {
    final half = _visiblePages ~/ 2;
    final total = BibleBooks.totalPages;
    _winStart = (_idx - half)
        .clamp(0, total - _visiblePages)
        .toDouble();
    if (_visiblePages > 1) {
      _thumbRatio = (_idx - _winStart) / (_visiblePages - 1);
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  ({double v, int dir}) _velocityFromFx(double fx, double width) {
    if (width <= 0) return (v: 0, dir: 0);
    if (fx < 0) return (v: 400, dir: -1);
    if (fx > width) return (v: 400, dir: 1);
    final leftPct = fx / width;
    final rightPct = (width - fx) / width;
    final isLeft = leftPct <= rightPct;
    final pct = isLeft ? leftPct : rightPct;
    final dir = isLeft ? -1 : 1;
    double v = 0;
    if (pct < 0.05) {
      v = 200;
    } else if (pct < 0.10) {
      v = 80;
    } else if (pct < 0.20) {
      v = 30;
    } else if (pct < 0.35) {
      v = 8;
    } else {
      return (v: 0, dir: 0);
    }
    return (v: v, dir: dir);
  }

  void _updateIdx() {
    final total = BibleBooks.totalPages;
    _idx = (_winStart + _thumbRatio * (_visiblePages - 1))
        .clamp(0, total - 1);
  }

  void _startAutoScroll() {
    _lastTickTime = null;
    if (!_tickerRunning) {
      _ticker.start();
      _tickerRunning = true;
    }
  }

  void _stopAutoScroll() {
    if (_tickerRunning) {
      _ticker.stop();
      _tickerRunning = false;
    }
    _lastTickTime = null;
  }

  void _onTick(Duration elapsed) {
    if (!_active || _velocityMag == 0) return;
    final dt = _lastTickTime != null
        ? (elapsed - _lastTickTime!).inMicroseconds / 1e6
        : 0.0;
    _lastTickTime = elapsed;
    if (dt <= 0 || dt > 0.05) return;

    final total = BibleBooks.totalPages;
    setState(() {
      _winStart = (_winStart + _velocityMag * _velocityDir * dt)
          .clamp(0, total - _visiblePages)
          .toDouble();
      _updateIdx();
    });
  }

  void _updateFromPointer(double globalX) {
    final stripBox =
        _stripKey.currentContext?.findRenderObject() as RenderBox?;
    if (stripBox == null || !stripBox.hasSize) return;
    final stripPos = stripBox.localToGlobal(Offset.zero);
    final stripWidth = stripBox.size.width;
    final fx = globalX - stripPos.dx;
    final ratio = (fx / stripWidth).clamp(0.0, 1.0);
    final vel = _velocityFromFx(fx, stripWidth);

    setState(() {
      _thumbRatio = ratio;
      _velocityMag = vel.v;
      _velocityDir = vel.dir;
      _updateIdx();
    });

    if (vel.v > 0 && !_tickerRunning) {
      _startAutoScroll();
    } else if (vel.v == 0) {
      _stopAutoScroll();
    }
  }

  void _activate(double globalX) {
    setState(() => _active = true);
    // Wait one frame for the strip to be laid out, then update from pointer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _active) {
        _updateFromPointer(globalX);
      }
    });
  }

  void _deactivate() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pointerStart = null;
    _stopAutoScroll();

    if (_active) {
      final info = BibleBooks.globalPageToBookInfo(_idx.round());
      widget.onNavigate(info.book.id, info.localPage);
    }

    setState(() {
      _active = false;
      _velocityMag = 0;
      _velocityDir = 0;
      _centerWindow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = BibleBooks.globalPageToBookInfo(_idx.round());
    final raiseY = _active ? _activeRaise : 0.0;

    // The Listener wraps the entire scrubber so the full bar is the hit area
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _pointerStart = event.position;
        _holdTimer?.cancel();
        final gx = event.position.dx;
        _holdTimer = Timer(const Duration(milliseconds: 180), () {
          if (mounted) _activate(gx);
        });
      },
      onPointerMove: (event) {
        if (_active) {
          _updateFromPointer(event.position.dx);
        } else if (_pointerStart != null) {
          final delta = event.position - _pointerStart!;
          if (delta.distance > 8) {
            _holdTimer?.cancel();
            _holdTimer = null;
            _activate(event.position.dx);
          }
        }
      },
      onPointerUp: (_) => _deactivate(),
      onPointerCancel: (_) => _deactivate(),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAFAFA),
          border: Border(
            top: BorderSide(color: Color(0xFFE4E4E7)),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(
          height: _stripHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Page label — centered at rest, floats above strip when active
              Positioned(
                left: 0,
                right: 0,
                bottom: _active
                    ? _stripHeight + raiseY + 16
                    : 8,
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      '${info.book.abbr} ${info.localPage + 1}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF18181B),
                        letterSpacing: -0.05,
                      ),
                    ),
                  ),
                ),
              ),

              // The strip — hidden at rest, rises on activation
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: _active
                      ? const Duration(milliseconds: 120)
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(0, -raiseY, 0),
                  child: AnimatedOpacity(
                    opacity: _active ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      key: _stripKey,
                      height: _stripHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _active ? _buildStripContents() : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStripContents() {
    final total = BibleBooks.totalPages;
    final winEnd =
        (_winStart + _visiblePages - 1).clamp(0, total - 1).toInt();
    final windowBooks = <_WindowBook>[];

    for (int p = _winStart.floor(); p <= winEnd; p++) {
      final pi = BibleBooks.globalPageToBookInfo(p);
      if (windowBooks.isNotEmpty && windowBooks.last.bookId == pi.book.id) {
        windowBooks.last.end = p;
      } else {
        final bookIdx =
            BibleBooks.books.indexWhere((b) => b.id == pi.book.id);
        windowBooks.add(_WindowBook(
          bookId: pi.book.id,
          abbr: pi.book.abbr,
          bookIndex: bookIdx,
          start: p,
          end: p,
        ));
      }
    }

    final currentBookId =
        BibleBooks.globalPageToBookInfo(_idx.round()).book.id;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stripWidth = constraints.maxWidth;

        return Stack(
          children: [
            // Dividers between books
            for (int i = 0; i < windowBooks.length - 1; i++)
              Builder(builder: (_) {
                final bk = windowBooks[i];
                final dividerLeftR =
                    (bk.end + 1 - _winStart) / _visiblePages;
                return Positioned(
                  left: dividerLeftR * stripWidth,
                  top: 0,
                  bottom: 0,
                  width: 1,
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                );
              }),

            // Book abbreviation labels
            for (final bk in windowBooks)
              Builder(builder: (_) {
                final bookStart =
                    BibleBooks.pageStartForIndex(bk.bookIndex);
                final bookEnd = bookStart +
                    BibleBooks.books[bk.bookIndex].pageCount -
                    1;
                final anchorR = ((bookStart > _winStart
                                ? bookStart
                                : _winStart) -
                            _winStart) /
                    _visiblePages;
                final maxR = (bookEnd + 1 - _winStart) / _visiblePages;
                final isCurrent = bk.bookId == currentBookId;
                final visWidthR =
                    (bk.end - bk.start + 1) / _visiblePages;
                if (visWidthR * 100 <= 6) return const SizedBox.shrink();
                return Positioned(
                  left: anchorR * stripWidth + 8,
                  top: 0,
                  bottom: 0,
                  width: ((maxR - anchorR) * stripWidth - 12)
                      .clamp(0, stripWidth),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      bk.abbr,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: Colors.white
                            .withValues(alpha: isCurrent ? 1.0 : 0.55),
                        letterSpacing: 0.1,
                        height: 1.1,
                      ),
                    ),
                  ),
                );
              }),

            // Thumb / playhead
            Positioned(
              left: _thumbRatio * stripWidth - 1.5,
              top: -3,
              bottom: -3,
              width: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.15),
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WindowBook {
  final String bookId;
  final String abbr;
  final int bookIndex;
  final int start;
  int end;

  _WindowBook({
    required this.bookId,
    required this.abbr,
    required this.bookIndex,
    required this.start,
    required this.end,
  });
}
