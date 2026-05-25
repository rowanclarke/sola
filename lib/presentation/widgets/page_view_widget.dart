import 'package:flutter/material.dart';

import '../../core/models/page_model.dart';

class PageViewWidget extends StatelessWidget {
  final PageModel page;

  const PageViewWidget({
    super.key,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Page ${page.pageNumber}',
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w300,
          color: Color(0xFF18181B),
          letterSpacing: -1,
        ),
      ),
    );
  }
}
