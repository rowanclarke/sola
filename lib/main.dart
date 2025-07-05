import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ui/pagination/view_model/pagination_view_model.dart';
import 'data/services/page_service.dart';
import 'data/repositories/page_repository.dart';
import 'ui/pagination/widgets/pagination_screen.dart';

void main() {
  final service = PageService();
  final repository = PageRepository(service);
  runApp(MyApp(repository: repository));
}

class MyApp extends StatelessWidget {
  final PageRepository repository;
  const MyApp({required this.repository, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PaginationViewModel(repository: repository),
        ),
      ],
      child: MaterialApp(home: PaginationScreen()),
    );
  }
}
