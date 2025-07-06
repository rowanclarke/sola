import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sola/data/services/renderer_service.dart';
import 'ui/pagination/view_model/pagination_view_model.dart';
import 'data/services/bible_service.dart';
import 'data/repositories/page_repository.dart';
import 'ui/pagination/widgets/pagination_screen.dart';

void main() {
  final service = BibleService();
  final renderer = RendererService();
  final repository = PageRepository(
    service,
    renderer,
    'https://ebible.org/Scriptures/engwebpb_usfm.zip',
    '02-GENengwebpb.usfm',
  );
  runApp(MyApp(repository: repository));
}

class MyApp extends StatelessWidget {
  final PageRepository repository;
  const MyApp({required this.repository, super.key});

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding.top;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PaginationViewModel(repository: repository),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: child!,
          );
        },
        home: Scaffold(body: PaginationScreen(padding)),
      ),
    );
  }
}
