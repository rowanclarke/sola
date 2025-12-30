import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sola/data/repositories/embedding_repository.dart';
import 'package:sola/data/repositories/library_repository.dart';
import 'package:sola/data/repositories/search_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';
import 'package:sola/data/services/file_service.dart';
import 'package:sola/data/services/renderer_service.dart';
import 'package:sola/data/services/search_service.dart';
import 'package:sola/ui/home/view_model/home_view_model.dart';
import 'package:sola/ui/home/widgets/home_screen.dart';
import 'package:sola/ui/menu/view_model/menu_view_model.dart';
import 'package:sola/ui/search/view_model/search_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fileService = FileService(await getApplicationSupportDirectory());
  await fileService.deleteFile("session");
  final sessionRepository = SessionRepository(fileService.file("session"));
  final libraryRepository = LibraryRepository(
    await fileService.deserializeAsset("assets/translations.json"),
    fileService.directory("library"),
    fileService.directory("serialized"),
    fileService.directory("rendered"),
  );
  final rendererService = RendererService();
  final searchService = SearchService(fileService);
  final _embeddingRepository = EmbeddingRepository(fileService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(
            sessionRepository,
            libraryRepository,
            rendererService,
          )..init(),
        ),
        ChangeNotifierProvider(create: (_) => MenuViewModel()),
        ChangeNotifierProvider(
          create: (context) {
            final homeVm = context.read<HomeViewModel>();
            return SearchViewModel(
              SearchRepository(
                // Will be set dynamically based on current translation
                libraryRepository as dynamic,
                fileService,
                searchService,
              ),
              currentTranslationId: homeVm.currentTranslationId,
            );
          },
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
    ),
  );
}
