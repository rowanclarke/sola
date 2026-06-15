import 'package:flutter/material.dart';
import 'package:rust/rust.dart' as rust;

import '../../core/models/page_model.dart';

class PageViewWidget extends StatelessWidget {
  final PageModel page;
  final double width;
  final double height;

  const PageViewWidget({
    super.key,
    required this.page,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? Colors.black;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: _PagePainter(page.page, color),
      ),
    );
  }
}

class _PagePainter extends CustomPainter {
  final List<rust.Text> fragments;
  final Color defaultColor;

  _PagePainter(this.fragments, this.defaultColor);

  @override
  void paint(Canvas canvas, Size size) {
    for (final fragment in fragments) {
      final style = fragment.style.color == null
          ? fragment.style.copyWith(color: defaultColor)
          : fragment.style;
      final painter = TextPainter(
        text: TextSpan(text: fragment.text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textHeightBehavior: const TextHeightBehavior(
          leadingDistribution: TextLeadingDistribution.even,
        ),
      );
      painter.layout();
      painter.paint(canvas, Offset(fragment.rect.left, fragment.rect.top));
    }
  }

  @override
  bool shouldRepaint(_PagePainter oldDelegate) =>
      !identical(oldDelegate.fragments, fragments);
}
