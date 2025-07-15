import 'package:flutter/material.dart';

import '../../pagination/widgets/pagination_screen.dart';
import '../../search/widgets/search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding.top;
    return Scaffold(body: SearchScreen(child: PaginationScreen(padding)));
  }
}
