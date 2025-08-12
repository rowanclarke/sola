import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/repositories/usfm_repository.dart';
import 'package:sola/data/services/usfm_service.dart';

import 'ui/home/view_model/home_view_model.dart';
import 'ui/home/widgets/home_screen.dart';
import 'ui/search/view_model/search_view_model.dart';
import 'ui/pagination/view_model/pagination_view_model.dart';
import 'data/repositories/page_repository.dart';
import 'data/repositories/search_repository.dart';
import 'data/services/renderer_service.dart';
import 'data/services/search_service.dart';
import 'data/services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final extern = await getApplicationDocumentsDirectory();
  final storageService = StorageService(extern);
  await storageService.deleteDirectory("assets/model.zip");
  final modelService = await storageService.extractAsset("assets/model.zip");
  final bibleService = await storageService.extractRemote(
    "https://ebible.org/Scriptures/engwebpb_usfm.zip",
  );
  final rendererService = RendererService();
  final searchService = SearchService();
  final usfmService = UsfmService();
  final usfmFileService = storageService.local("usfm");
  final rendererFileService = storageService.local("renderer");
  final usfmRepository = UsfmRepository(
    bibleService,
    usfmService,
    usfmFileService,
  );
  await usfmRepository.loadBooks();
  final rendererRepository = RendererRepository(
    usfmRepository,
    rendererService,
    rendererFileService,
  );
  runApp(
    MyApp(
      pageRepository: PageRepository(usfmRepository, rendererRepository),
      searchRepository: SearchRepository(
        rendererRepository,
        modelService,
        searchService,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final PageRepository pageRepository;
  final SearchRepository searchRepository;
  const MyApp({
    required this.pageRepository,
    required this.searchRepository,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PaginationViewModel(pageRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchViewModel(searchRepository),
        ),
        Provider<HomeViewModel>(
          create: (context) => HomeViewModel(
            "GEN",
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
