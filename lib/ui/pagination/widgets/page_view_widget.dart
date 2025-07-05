import 'package:flutter/material.dart';

class PageViewWidget extends StatelessWidget {
  final bool isLoading;
  final String? text;

  const PageViewWidget({required this.isLoading, this.text, super.key});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Text(text ?? 'No content', style: TextStyle(fontSize: 24)),
    );
  }
}
