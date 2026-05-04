import 'package:flutter/material.dart';

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
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: page.page.map((text) {
          final rect = text.rect;
          return Positioned(
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            child: Text(
              text.text,
              style: text.style,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          );
        }).toList(),
      ),
    );
  }
}
