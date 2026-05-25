import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/repositories/session_repository.dart';
import '../domain/services/file_service.dart';
import '../presentation/viewmodels/reader_viewmodel.dart';
import 'app_routes.dart';

class AppBootstrap {
  static Future<Widget> initialize() async {
    debugPrint('[Bootstrap] Initializing app...');
    final dir = await getApplicationSupportDirectory();
    debugPrint('[Bootstrap] App directory: ${dir.path}');
    final fileService = FileService(dir);

    final sessionRepository = SessionRepository(fileService: fileService);
    await sessionRepository.init();

    // Ensure a default book is set
    if (sessionRepository.currentSession.currentBookId == null) {
      await sessionRepository.setCurrentBook('GEN');
    }

    final readerViewModel = ReaderViewModel(
      sessionRepository: sessionRepository,
    );

    debugPrint('[Bootstrap] All services and viewmodels created');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: readerViewModel),
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
      initialRoute: AppRoutes.reader,
    );
  }
}
