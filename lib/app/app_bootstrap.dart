/// Application bootstrap and dependency injection setup.
///
/// Creates all dependencies in order:
/// 1. Domain services (no dependencies on each other or UI)
/// 2. Data repositories (depend on services)
/// 3. Presentation viewmodels (depend on repositories)
/// 4. Provider configuration (makes viewmodels available to widget tree)

import 'package:flutter/material.dart';
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

/// Initializes all application dependencies and returns the root widget tree.
///
/// Order matters:
/// - FileService first (no dependencies)
/// - Other services (depend on FileService)
/// - SessionRepository first among repositories
/// - Other repositories (depend on services and SessionRepository)
/// - ViewModels (depend on repositories)
class AppBootstrap {
  /// Initializes all dependencies and returns the root widget wrapped in providers.
  static Future<Widget> initialize() async {
    // 1. Domain services
    final fileService = FileService();
    final bibleService = BibleService();
    final rendererService = RendererService();
    final searchService = SearchService();

    // 2. Repositories
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
    );
    final searchRepository = SearchRepository(
      fileService: fileService,
      searchService: searchService,
      bibleRepository: bibleRepository,
    );

    // 3. Session state
    final sessionState = SessionState(
      initialSession: sessionRepository.currentSession,
    );

    // 4. ViewModels
    final sessionViewModel = SessionViewModel(
      sessionRepository: sessionRepository,
    );
    final libraryViewModel = LibraryViewModel(
      libraryRepository: libraryRepository,
      sessionRepository: sessionRepository,
    );
    final renderingViewModel = RenderingViewModel(
      rendererRepository: rendererRepository,
      sessionRepository: sessionRepository,
    );
    final readerViewModel = ReaderViewModel(
      rendererRepository: rendererRepository,
      sessionRepository: sessionRepository,
    );
    final searchViewModel = SearchViewModel(
      searchRepository: searchRepository,
      sessionRepository: sessionRepository,
    );

    // 5. Build provider tree
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

/// Root widget for the Sola application.
class SolaApp extends StatelessWidget {
  const SolaApp({super.key});

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}
