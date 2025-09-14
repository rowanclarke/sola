import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:sola/data/repositories/renderer_repository.dart';
import 'package:sola/data/services/bible_service.dart';
import 'package:sola/data/services/file_service.dart';
import 'package:sola/data/services/renderer_service.dart';

class BibleRepository {
  final BibleService bibleService = BibleService();
  final FileService rawFileService;
  final FileService usfmFileService;
  final FileService rendererFileService;
  final RendererService rendererService;

  BibleRepository(
    this.rawFileService,
    this.usfmFileService,
    this.rendererFileService,
    this.rendererService,
  );

  Future<void> init() async {
    if (!await usfmFileService.exists()) {
      for (File file in await rawFileService.getFiles()) {
        print(file.uri);
        Uint8List bytes = await bibleService.serialize(
          await file.readAsString(),
        );
        Pointer<Void> archived = await bibleService.getArchived(bytes);
        String identifier = bibleService.getIdentifier(archived);
        await usfmFileService.file(identifier).writeAsBytes(bytes);
      }
    }
  }

  Future<RendererRepository> getBook(
    String book,
    double width,
    double height,
  ) async {
    final rendererRepository = RendererRepository(
      book,
      rendererService,
      rendererFileService.directory(book),
    );
    await rendererRepository.init(
      () async => await usfmFileService
          .readAsBytes(book)
          .then((bytes) async => await bibleService.getArchived(bytes)),
      width,
      height,
    );
    return rendererRepository;
  }
}
