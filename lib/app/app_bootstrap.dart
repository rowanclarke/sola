import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/session/session_state.dart';
import '../data/repositories/bible_repository.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/renderer_repository.dart';
import '../data/repositories/search_repository.dart';
import '../data/repositories/session_repository.dart';
import '../domain/services/bible_service.dart';
import '../domain/services/file_service.dart';
import '../domain/services/renderer_service.dart';
import '../domain/services/search_service.dart';
import '../presentation/viewmodels/library_viewmodel.dart';
import '../presentation/viewmodels/reader_viewmodel.dart';
import '../presentation/viewmodels/rendering_viewmodel.dart';
import '../presentation/viewmodels/search_viewmodel.dart';
import '../presentation/viewmodels/session_viewmodel.dart';
import 'app_routes.dart';

class AppBootstrap {
  static Future<Widget> initialize() async {
    final dir = await getApplicationSupportDirectory();
    final fileService = FileService(dir);
    final bibleService = BibleService();
    final rendererService = RendererService();
    final searchService = SearchService();

    rendererService.registerStyles();

    final sessionRepository = SessionRepository(fileService: fileService);
    await sessionRepository.init();

    final libraryRepository = LibraryRepository(fileService: fileService);
    final bibleRepository = BibleRepository(
      fileService: fileService,
      bibleService: bibleService,
    );
    final rendererRepository = RendererRepository(
      fileService: fileService,
      rendererService: rendererService,
      bibleRepository: bibleRepository,
      bibleService: bibleService,
    );
    final searchRepository = SearchRepository(
      fileService: fileService,
      searchService: searchService,
      rendererRepository: rendererRepository,
    );

    final sessionState = SessionState(
      initialSession: sessionRepository.currentSession,
    );

    final sessionViewModel = SessionViewModel(
      sessionRepository: sessionRepository,
    );
    final libraryViewModel = LibraryViewModel(
      libraryRepository: libraryRepository,
      sessionRepository: sessionRepository,
    );
    final renderingViewModel = RenderingViewModel();
    final readerViewModel = ReaderViewModel(
      rendererRepository: rendererRepository,
      sessionRepository: sessionRepository,
      bibleRepository: bibleRepository,
    );
    final searchViewModel = SearchViewModel(
      searchRepository: searchRepository,
      sessionRepository: sessionRepository,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sessionState),
        ChangeNotifierProvider.value(value: sessionViewModel),
        ChangeNotifierProvider.value(value: libraryViewModel),
        ChangeNotifierProvider.value(value: renderingViewModel),
        ChangeNotifierProvider.value(value: readerViewModel),
        ChangeNotifierProvider.value(value: searchViewModel),
      ],
      child: const SolaApp(),
    );
  }
}

class SolaApp extends StatelessWidget {
  const SolaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
      onGenerateRoute: AppRouteGenerator.generateRoute,
      initialRoute: AppRoutes.library,
    );
  }
}
