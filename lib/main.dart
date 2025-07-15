import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'ui/home/view_model/home_view_model.dart';
import 'ui/home/widgets/home_screen.dart';
import 'ui/search/view_model/search_view_model.dart';
import 'ui/pagination/view_model/pagination_view_model.dart';
import 'data/services/bible_service.dart';
import 'data/repositories/page_repository.dart';
import 'data/services/renderer_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = BibleService();
  final renderer = RendererService();
  final repository = PageRepository(
    service,
    renderer,
    await getApplicationDocumentsDirectory(),
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PaginationViewModel(repository: repository),
        ),
        ChangeNotifierProvider(create: (_) => SearchViewModel()),
        Provider<HomeViewModel>(
          create: (context) => HomeViewModel(
            pagination: context.read<PaginationViewModel>(),
            search: context.read<SearchViewModel>(),
          ),
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
        home: Scaffold(body: HomeScreen()),
      ),
    );
  }
}
