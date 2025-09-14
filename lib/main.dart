import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sola/data/repositories/library_repository.dart';
import 'package:sola/data/repositories/session_repository.dart';
import 'package:sola/data/services/file_service.dart';
import 'package:sola/data/services/renderer_service.dart';
import 'package:sola/ui/home/view_model/home_view_model.dart';
import 'package:sola/ui/home/widgets/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fileService = FileService(await getApplicationSupportDirectory());
  print(fileService.dir.path);
  // await fileService.deleteFile("session");
  final sessionRepository = SessionRepository(fileService.file("session"));
  final libraryRepository = LibraryRepository(
    fileService.directory("library"),
    await fileService.deserializeAsset("assets/translations.json", "id"),
    fileService.directory("serialized"),
    fileService.directory("rendered"),
  );
  final rendererService = RendererService();

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
      ],
      child: MaterialApp(home: Scaffold(body: HomeScreen())),
    ),
  );
}
