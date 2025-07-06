import 'package:flutter/material.dart';

class PageViewWidget extends StatelessWidget {
  final bool isLoading;
  final Widget? widget;

  const PageViewWidget({required this.isLoading, this.widget, super.key});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    return widget!;
  }
}
