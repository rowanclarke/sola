import 'package:flutter/material.dart';

/// Animated search pull-down panel.
///
/// Single search icon exists across all phases:
///   idle    — icon centered in panel, bordered box, tappable
///   pulling — same icon translates down with finger
///   focused — icon bounces to left (spring), text field grows in
///
/// Dismiss (close button, focus loss) animates the icon back to center
/// with the same spring curve.
class ReaderTopPanel extends StatefulWidget {
  const ReaderTopPanel({super.key});

  @override
  ReaderTopPanelState createState() => ReaderTopPanelState();
}

class ReaderTopPanelState extends State<ReaderTopPanel>
    with SingleTickerProviderStateMixin {
  static const double panelHeight = 52;
  static const double _pullThreshold = 36;
  static const double _pullMax = 96;
  static const Cubic _spring = Cubic(0.34, 1.56, 0.64, 1.0);

  _Phase _phase = _Phase.idle;
  double _pullPx = 0;
  double _pullAtFocus = 0;
  bool _dismissing = false;

  // Always animate forward; swap _animFrom/_animTo for direction.
  // This ensures the spring overshoot always lands at the TARGET end.
  double _animFrom = 0.0;
  double _animTo = 1.0;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late AnimationController _animController;

  /// Current spring-curved value interpolated from [_animFrom] to [_animTo].
  double get _progress {
    final t = _spring.transform(_animController.value);
    return _animFrom + (_animTo - _animFrom) * t;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _animController.addStatusListener(_onAnimStatus);
    _animController.addListener(() => setState(() {}));
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _animController.removeStatusListener(_onAnimStatus);
    _focusNode.removeListener(_onFocusChange);
    _animController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _dismissing) {
      _dismissing = false;
      _pullAtFocus = 0;
      if (mounted) {
        setState(() {
          _phase = _Phase.idle;
          _pullPx = 0;
        });
      }
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _phase == _Phase.focused && !_dismissing) {
      _dismiss();
    }
  }

  // --- Public API for external drag input (called from ReaderScreen) ---

  void handleDragUpdate(double dy) {
    if (_phase == _Phase.focused) return;
    if (dy <= 0) {
      if (_phase == _Phase.pulling) {
        setState(() {
          _phase = _Phase.idle;
          _pullPx = 0;
        });
      }
      return;
    }
    setState(() {
      _phase = _Phase.pulling;
      _pullPx = dy.clamp(0, _pullMax);
    });
  }

  bool handleDragEnd() {
    if (_phase == _Phase.focused) return false;
    final triggered = _pullPx >= _pullThreshold;
    if (triggered) {
      _focusSearch();
    } else {
      setState(() {
        _phase = _Phase.idle;
        _pullPx = 0;
      });
    }
    return triggered;
  }

  void _focusSearch() {
    _dismissing = false;
    _pullAtFocus = _pullPx;
    _animFrom = 0.0;
    _animTo = 1.0;
    setState(() {
      _phase = _Phase.focused;
      _pullPx = 0;
    });
    _animController.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _pullAtFocus = 0;
    _animFrom = 1.0;
    _animTo = 0.0;
    _textController.clear();
    _focusNode.unfocus();
    _animController.forward(from: 0);
  }

  bool get isFocused => _phase == _Phase.focused;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final centerX = screenWidth / 2 - 17;
    const focusedX = 16.0;

    final p = _progress;
    final pClamped = p.clamp(0.0, 1.0);

    return Container(
      height: panelHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE4E4E7)),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // === Single search icon — present in ALL phases ===
          Positioned(
            left: 0,
            top: (panelHeight - 34) / 2,
            child: Builder(builder: (context) {
              final x = centerX + (focusedX - centerX) * p;
              final double pullY;
              if (_phase == _Phase.pulling) {
                pullY = _pullPx;
              } else if (_pullAtFocus > 0 &&
                  _animController.isAnimating &&
                  _animTo == 1.0) {
                pullY = _pullAtFocus * (1 - pClamped);
              } else {
                pullY = 0;
              }
              return Transform.translate(
                offset: Offset(x, pullY),
                child: GestureDetector(
                  onTap: () {
                    if (_phase != _Phase.focused && !_dismissing) {
                      _focusSearch();
                    }
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Color.fromRGBO(228, 228, 231, 1.0 - pClamped),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.search,
                        size: 16,
                        color: Color(0xFF52525B),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          // === Pull-down hint text ===
          if (_phase == _Phase.pulling && _pullPx > 8)
            Positioned(
              left: 0,
              right: 0,
              top: panelHeight / 2 + _pullPx + 22,
              child: IgnorePointer(
                child: Text(
                  _pullPx >= _pullThreshold
                      ? 'RELEASE TO SEARCH'
                      : 'PULL TO SEARCH',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: _pullPx >= _pullThreshold
                        ? const Color(0xFF18181B)
                        : const Color(0xFF71717A),
                  ),
                ),
              ),
            ),

          // === Focused / dismissing: text field + close button ===
          if (_phase == _Phase.focused || _dismissing)
            Positioned(
              top: 0,
              bottom: 0,
              left: 58,
              right: 16,
              child: Opacity(
                opacity: pClamped,
                child: Transform.translate(
                  offset: Offset(-8 * (1 - pClamped), 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F5),
                            border: Border.all(
                              color: const Color(0xFFE4E4E7),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF18181B),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search verses, books, words...',
                              hintStyle: TextStyle(
                                color: Color(0xFF71717A),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _dismiss,
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Center(
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Color(0xFF71717A),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // === Settings icon — right side, hidden while focused ===
          Positioned(
            right: 16,
            top: (panelHeight - 34) / 2,
            child: Opacity(
              opacity: 1.0 - pClamped,
              child: IgnorePointer(
                ignoring: _phase == _Phase.focused || _dismissing,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    border: Border.all(
                      color: const Color(0xFFE4E4E7),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.settings,
                      size: 15,
                      color: Color(0xFF52525B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Phase { idle, pulling, focused }
