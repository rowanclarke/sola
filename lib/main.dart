import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'ui/home/view_model/home_view_model.dart';
import 'ui/home/widgets/home_screen.dart';
import 'ui/search/view_model/search_view_model.dart';
import 'ui/pagination/view_model/pagination_view_model.dart';
import 'data/services/bible_service.dart';
import 'data/repositories/page_repository.dart';
import 'data/repositories/search_repository.dart';
import 'data/services/renderer_service.dart';
import 'data/services/search_service.dart';
import 'data/services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final extern = await getApplicationDocumentsDirectory();
  final storageService = StorageService(extern);
  final modelService = await storageService.extractAsset("assets/model.zip");
  final bibleService = BibleService();
  final rendererService = RendererService();
  final searchService = SearchService();
  runApp(
    MyApp(
      pageRepository: PageRepository(
        bibleService,
        rendererService,
        extern,
        'https://ebible.org/Scriptures/engwebpb_usfm.zip',
        '02-GENengwebpb.usfm',
      ),
      searchRepository: SearchRepository(modelService, searchService),
    ),
  );
}

class MyApp extends StatelessWidget {
  final PageRepository pageRepository;
  final SearchRepository searchRepository;
  MyApp({
    required this.pageRepository,
    required this.searchRepository,
    super.key,
  }) {
    searchRepository.loadModel();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PaginationViewModel(repository: pageRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchViewModel(searchRepository),
        ),
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
