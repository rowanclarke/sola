import 'package:flutter/material.dart';
import 'package:rust/rust.dart' as rust;

class PageViewWidget extends StatelessWidget {
  final List<rust.Text>? builder;
  final double width;
  final double height;

  const PageViewWidget({
    this.builder,
    required this.width,
    required this.height,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children:
            builder?.map((text) {
              final rect = text.rect;
              return Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: Text(text.text, style: text.style, softWrap: false),
              );
            }).toList() ??
            [Container()],
      ),
    );
  }
}
