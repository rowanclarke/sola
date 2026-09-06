import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/repositories/bible_repository.dart';
import '../data/repositories/language_repository.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/renderer_repository.dart';
import '../data/repositories/search_repository.dart';
import '../data/repositories/session_repository.dart';
import '../domain/services/file_service.dart';
import '../domain/services/model_service.dart';
import '../domain/services/renderer_service.dart';
import '../presentation/viewmodels/onboarding_viewmodel.dart';
import '../presentation/viewmodels/reader_viewmodel.dart';
import '../presentation/viewmodels/search_viewmodel.dart';
import '../presentation/viewmodels/settings_viewmodel.dart';
import 'app_routes.dart';

class AppBootstrap {
  static Future<Widget> initialize() async {
    debugPrint('[Bootstrap] Initializing app...');
    final dir = await getApplicationSupportDirectory();
    debugPrint('[Bootstrap] App directory: ${dir.path}');
    final fileService = FileService(dir);
    final rendererService = RendererService();

    rendererService.registerStyles();

    final sessionRepository = SessionRepository(fileService: fileService);
    await sessionRepository.init();

    if (sessionRepository.currentSession.currentBookId == null) {
      await sessionRepository.setCurrentBook('GEN');
    }

    final libraryRepository = LibraryRepository(fileService: fileService);
    final languageRepository = LanguageRepository(
      fileService: fileService,
      libraryRepository: libraryRepository,
    );
    final bibleRepository = BibleRepository(
      fileService: fileService,
    );
    final rendererRepository = RendererRepository(
      fileService: fileService,
      rendererService: rendererService,
      bibleRepository: bibleRepository,
    );
    final modelService = ModelService(fileService: fileService);
    final searchRepository = SearchRepository(
      fileService: fileService,
      modelService: modelService,
    );

    final onboardingViewModel = OnboardingViewModel(
      languageRepository: languageRepository,
      libraryRepository: libraryRepository,
      sessionRepository: sessionRepository,
      bibleRepository: bibleRepository,
    );
    final readerViewModel = ReaderViewModel(
      rendererRepository: rendererRepository,
      sessionRepository: sessionRepository,
    );
    final searchViewModel = SearchViewModel(
      searchRepository: searchRepository,
      sessionRepository: sessionRepository,
    );
    final settingsViewModel = SettingsViewModel(
      fileService: fileService,
      bibleRepository: bibleRepository,
      rendererRepository: rendererRepository,
      searchRepository: searchRepository,
    );

    // Determine initial route based on session state
    final session = sessionRepository.currentSession;
    final hasCompletedOnboarding = session.currentLanguageCode != null
        && session.currentTranslationId != null;
    final initialRoute = hasCompletedOnboarding
        ? AppRoutes.reader
        : AppRoutes.language;

    debugPrint('[Bootstrap] Initial route: $initialRoute');
    debugPrint('[Bootstrap] All services and viewmodels created');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: onboardingViewModel),
        ChangeNotifierProvider.value(value: readerViewModel),
        ChangeNotifierProvider.value(value: searchViewModel),
        ChangeNotifierProvider.value(value: settingsViewModel),
      ],
      child: SolaApp(initialRoute: initialRoute),
    );
  }
}

class SolaApp extends StatelessWidget {
  final String initialRoute;

  const SolaApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
      onGenerateRoute: AppRouteGenerator.generateRoute,
      initialRoute: initialRoute,
    );
  }
}
